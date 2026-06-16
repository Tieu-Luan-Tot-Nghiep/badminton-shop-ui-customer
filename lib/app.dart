import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'admin/datasources/admin_remote_data_source.dart';
import 'admin/pages/admin_dashboard_page.dart';
import 'admin/pages/admin_orders_page.dart';
import 'admin/pages/admin_products_page.dart';
import 'admin/pages/admin_returns_page.dart';
import 'admin/pages/admin_system_page.dart';
import 'admin/pages/admin_users_page.dart';
import 'admin/widgets/admin_shell.dart';
import 'data/datasources/home_local_data_source.dart';
import 'data/datasources/home_remote_data_source.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'data/datasources/cart_remote_data_source.dart';
import 'data/datasources/address_remote_data_source.dart';
import 'data/datasources/order_remote_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/home_repository_impl.dart';
import 'data/repositories/address_repository_impl.dart';
import 'data/repositories/order_repository_impl.dart';
import 'domain/usecases/get_home_data_usecase.dart';
import 'core/network/api_client.dart';
import 'presentation/manager/auth_controller.dart';
import 'presentation/manager/chatbot_controller.dart';
import 'presentation/manager/home_controller.dart';
import 'presentation/manager/chat_controller.dart';
import 'presentation/manager/address_controller.dart';
import 'presentation/manager/order_controller.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/email_verification_page.dart';
import 'presentation/pages/forgot_password_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/profile_page.dart';
import 'presentation/pages/register_page.dart';
import 'presentation/pages/reviews_page.dart';
import 'presentation/pages/product_detail_page.dart';
import 'presentation/pages/chatbot_page.dart';
import 'presentation/pages/scan_page.dart';
import 'presentation/pages/cart_page.dart';
import 'presentation/pages/shop_page.dart';
import 'presentation/pages/chat_page.dart';
import 'presentation/pages/splash_loading_page.dart';
import 'presentation/models/scan_search_payload.dart';
import 'presentation/widgets/app_shell.dart';

class BadmintonShopApp extends StatefulWidget {
  const BadmintonShopApp({super.key});

  @override
  State<BadmintonShopApp> createState() => _BadmintonShopAppState();
}

class _BadmintonShopAppState extends State<BadmintonShopApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  int _selectedIndex = 0;
  int _adminSelectedIndex = 0;
  bool _isBootstrapped = false;
  bool _isAdminMode = false;

  late final List<Widget> _pages;
  late final List<Widget> _adminPages;
  late final HomeController _homeController;
  late final AuthController _authController;
  late final ChatController _chatController;
  late final ChatbotController _chatbotController;
  late final AddressController _addressController;
  late final OrderController _orderController;
  late final CartRemoteDataSource _cartRemote;
  late final AdminRemoteDataSource _adminRemote;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ValueNotifier<int> _cartCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _chatCount = ValueNotifier<int>(0);
  final ValueNotifier<ScanSearchPayload?> _scanSearchResult =
      ValueNotifier<ScanSearchPayload?>(null);
  final ValueNotifier<String?> _selectedCategorySlug = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> _searchKeyword = ValueNotifier<String?>(null);
  static const _cameraPermissionPromptedKey = 'camera_permission_prompted_once';
  bool _isRequestingFirstCameraPermission = false;

  @override
  void initState() {
    super.initState();
    final remote = HomeRemoteDataSource();
    final local = HomeLocalDataSource();
    final repository = HomeRepositoryImpl(remote, local);
    final useCase = GetHomeDataUseCase(repository);
    _homeController = HomeController(useCase);

    final authRemote = AuthRemoteDataSource();
    final authRepository = AuthRepositoryImpl(authRemote);
    _authController = AuthController(authRepository);
    ApiClient.configureAuth(
      getAccessToken: () => _authController.session?.token,
      refreshAccessToken: () async {
        await _authController.refreshToken();
        return _authController.session?.token;
      },
    );
    _authController.addListener(_syncModeWithRole);
    _chatController = ChatController(_authController);
    _chatController.addListener(() {
      _chatCount.value = _chatController.unreadCount;
    });
    _chatbotController = ChatbotController(_authController);

    final addressRemote = AddressRemoteDataSource();
    final addressRepository = AddressRepositoryImpl(addressRemote);
    _addressController = AddressController(addressRepository, _authController);

    final orderRemote = OrderRemoteDataSource();
    final orderRepository = OrderRepositoryImpl(orderRemote);
    _orderController = OrderController(orderRepository, _authController);
    _adminRemote = AdminRemoteDataSource();

    _cartRemote = CartRemoteDataSource();
    _authController.restoreSession().then((_) {
      _syncModeWithRole();
    });
    _refreshCartCount();

    _pages = [
      HomePage(
        controller: _homeController,
        authController: _authController,
        cartCountListenable: _cartCount,
        chatCountListenable: _chatCount,
        onOpenCart: _openCartFromTopBar,
        onOpenChat: _openChatFromTopBar,
        onOpenShopChat: _openShopChatFromTopBar,
        onCategorySelected: (category) {
          _scanSearchResult.value = null;
          _searchKeyword.value = null;
          _selectedCategorySlug.value = category.slug;
          if (!mounted) {
            return;
          }
          setState(() => _selectedIndex = 1);
        },
        onSearchSubmitted: (keyword) {
          _scanSearchResult.value = null;
          _selectedCategorySlug.value = 'all';
          _searchKeyword.value = keyword;
          if (!mounted) {
            return;
          }
          setState(() => _selectedIndex = 1);
        },
        onNavigateToHome: _navigateToHome,
        onProductSelected: (product) {
          final navigator = _navigatorKey.currentState;
          if (navigator == null) {
            return;
          }

          navigator.push(
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(
                productId: product.id,
                initialProduct: product,
                authController: _authController,
                addressController: _addressController,
                orderController: _orderController,
                cartCountListenable: _cartCount,
                chatCountListenable: _chatCount,
                onOpenCart: _openCartFromTopBar,
                onOpenChat: _openChatFromTopBar,
                onOpenShopChat: _openShopChatFromTopBar,
                onRequireLogin: () {
                  navigator.pushNamed('/login');
                },
                onCartChanged: _refreshCartCount,
                onNavigateToHome: _navigateToHome,
              ),
            ),
          );
        },
      ),
      ShopPage(
        authController: _authController,
        cartCountListenable: _cartCount,
        chatCountListenable: _chatCount,
        scanSearchResultListenable: _scanSearchResult,
        categorySlugListenable: _selectedCategorySlug,
        searchKeywordListenable: _searchKeyword,
        onOpenCart: _openCartFromTopBar,
        onOpenChat: _openChatFromTopBar,
        onOpenShopChat: _openShopChatFromTopBar,
        onNavigateToHome: _navigateToHome,
        onRequireLogin: () {
          _navigatorKey.currentState?.pushNamed('/login');
        },
        onCartChanged: _refreshCartCount,
      ),
      ScanPage(
        authController: _authController,
        cartCountListenable: _cartCount,
        chatCountListenable: _chatCount,
        onOpenCart: _openCartFromTopBar,
        onOpenChat: _openChatFromTopBar,
        onOpenShopChat: _openShopChatFromTopBar,
        onNavigateToHome: _navigateToHome,
        onSearchResult: (payload) {
          _searchKeyword.value = null;
          _selectedCategorySlug.value = 'all';
          _scanSearchResult.value = payload;
          if (!mounted) {
            return;
          }
          setState(() => _selectedIndex = 1);
        },
      ),
      ReviewsPage(
        authController: _authController,
        cartCountListenable: _cartCount,
        chatCountListenable: _chatCount,
        onOpenCart: _openCartFromTopBar,
        onOpenChat: _openChatFromTopBar,
        onOpenShopChat: _openShopChatFromTopBar,
        onNavigateToHome: _navigateToHome,
      ),
      ProfilePage(
        controller: _authController,
        addressController: _addressController,
        orderController: _orderController,
        cartCountListenable: _cartCount,
        chatCountListenable: _chatCount,
        onOpenCart: _openCartFromTopBar,
        onOpenChat: _openChatFromTopBar,
        onOpenShopChat: _openShopChatFromTopBar,
        onNavigateToHome: _navigateToHome,
        onLoggedOut: () {
          if (!mounted) {
            return;
          }
          _cartCount.value = 0;
          setState(() => _selectedIndex = 0);
        },
      ),
    ];

    _adminPages = [
      AdminDashboardPage(
        authController: _authController,
        dataSource: _adminRemote,
      ),
      AdminOrdersPage(
        authController: _authController,
        dataSource: _adminRemote,
      ),
      AdminProductsPage(
        authController: _authController,
        dataSource: _adminRemote,
      ),
      AdminReturnsPage(
        authController: _authController,
        dataSource: _adminRemote,
      ),
      AdminUsersPage(authController: _authController, dataSource: _adminRemote),
      AdminSystemPage(
        authController: _authController,
        dataSource: _adminRemote,
        onNavigateToAdminTab: (index) {
          if (!mounted) {
            return;
          }
          setState(() => _adminSelectedIndex = index);
        },
      ),
    ];
  }

  @override
  void dispose() {
    _authController.removeListener(_syncModeWithRole);
    _homeController.dispose();
    _authController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = 0;
      _adminSelectedIndex = 0;
    });
    final nav = _navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  void _syncModeWithRole() {
    if (!mounted) {
      return;
    }

    final nextAdminMode = _authController.isAdmin;
    if (_isAdminMode == nextAdminMode) {
      return;
    }

    setState(() {
      _isAdminMode = nextAdminMode;
      _selectedIndex = 0;
      _adminSelectedIndex = 0;
    });
  }

  void _handleLoginSuccess(BuildContext routeContext) {
    _authController.clearMessages();
    _syncModeWithRole();

    if (mounted) {
      setState(() {
        _selectedIndex = 0;
        _adminSelectedIndex = 0;
      });
    }

    Navigator.of(routeContext).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext = _navigatorKey.currentContext;
      if (currentContext == null) {
        return;
      }

      ScaffoldMessenger.of(currentContext)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thành công'),
            duration: Duration(seconds: 2),
          ),
        );

      _refreshCartCount();
    });
  }

  Future<void> _refreshCartCount() async {
    await _authController.restoreSession();
    _syncModeWithRole();
    if (!_authController.isAuthenticated) {
      if (_cartCount.value != 0) {
        _cartCount.value = 0;
      }
      return;
    }

    try {
      final snapshot = await _cartRemote.getMyCart(
        accessToken: _authController.session!.token,
      );
      _cartCount.value = snapshot.totalQuantity;
    } catch (_) {
      // Keep previous badge value when temporary network issues happen.
    }
  }

  Future<void> _openCartFromTopBar() async {
    if (_isAdminMode) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Admin mode: cart user route is blocked.'),
            ),
          );
      }
      return;
    }

    await _authController.restoreSession();
    if (!_authController.isAuthenticated) {
      await _navigatorKey.currentState?.pushNamed('/login');
      await _authController.restoreSession();
      if (!_authController.isAuthenticated) {
        await _refreshCartCount();
        return;
      }
    }

    await _refreshCartCount();

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => CartPage(
          authController: _authController,
          addressController: _addressController,
          orderController: _orderController,
          selectedTabIndex: _selectedIndex,
          onTabChanged: (index) {
            if (!mounted) {
              return;
            }
            setState(() => _selectedIndex = index);
          },
          onOpenShop: () {
            navigator.pop();
            if (!mounted) {
              return;
            }
            setState(() => _selectedIndex = 1);
          },
          onRequireLogin: () {
            _navigatorKey.currentState?.pushNamed('/login');
          },
          onNavigateToHome: _navigateToHome,
        ),
      ),
    );

    await _refreshCartCount();
  }

  Future<void> _openChatFromTopBar() async {
    if (_isAdminMode) {
      if (mounted) {
        setState(() => _adminSelectedIndex = 4);
      }
      final context = _navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Admin mode: switched to System tab (admin inbox).',
              ),
            ),
          );
      }
      return;
    }

    await _authController.restoreSession();
    if (!_authController.isAuthenticated) {
      await _navigatorKey.currentState?.pushNamed('/login');
      await _authController.restoreSession();
      if (!_authController.isAuthenticated) return;
    }
    _navigatorKey.currentState?.pushNamed('/chatbot');
  }

  Future<void> _openShopChatFromTopBar() async {
    if (_isAdminMode) return;
    await _authController.restoreSession();
    if (!_authController.isAuthenticated) {
      await _navigatorKey.currentState?.pushNamed('/login');
      await _authController.restoreSession();
      if (!_authController.isAuthenticated) return;
    }
    _navigatorKey.currentState?.pushNamed('/chat');
  }

  Widget _buildBlockedForAdminPage(String routeName) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Route')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                'Route "$routeName" is blocked in admin mode.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  _navigatorKey.currentState?.popUntil(
                    (route) => route.isFirst,
                  );
                },
                child: const Text('Back to Admin Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? '';
    const blockedInAdmin = <String>{
      '/register',
      '/verify-email',
      '/forgot-password',
      '/chat',
      '/chatbot',
    };

    if (_isAdminMode && blockedInAdmin.contains(routeName)) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => _buildBlockedForAdminPage(routeName),
      );
    }

    switch (routeName) {
      case '/login':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => LoginPage(
            controller: _authController,
            onNavigateToHome: _navigateToHome,
            onLoginSuccess: () {
              _handleLoginSuccess(context);
            },
            onOpenForgotPassword: () {
              _authController.clearMessages();
              Navigator.of(context).pushNamed('/forgot-password');
            },
            onOpenRegister: () {
              _authController.clearMessages();
              Navigator.of(context).pushReplacementNamed('/register');
            },
          ),
        );
      case '/register':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => RegisterPage(
            controller: _authController,
            onNavigateToHome: _navigateToHome,
            onRegistered: (email) {
              _authController.clearMessages();
              Navigator.of(
                context,
              ).pushReplacementNamed('/verify-email', arguments: email);
            },
            onOpenLogin: () {
              _authController.clearMessages();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        );
      case '/verify-email':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) {
            final email =
                (settings.arguments as String?) ??
                (_authController.pendingVerificationEmail ?? '');

            return EmailVerificationPage(
              controller: _authController,
              email: email,
              onBackToLogin: () {
                _authController.clearMessages();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            );
          },
        );
      case '/forgot-password':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => ForgotPasswordPage(
            controller: _authController,
            onBackToLogin: () {
              Navigator.of(context).pop();
            },
          ),
        );
      case '/chat':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => ChatPage(controller: _chatController),
        );
      case '/chatbot':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => ChatbotPage(controller: _chatbotController),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Badminton Shop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => _buildBlockedForAdminPage(settings.name ?? 'unknown'),
      ),
      home: !_isBootstrapped
          ? SplashLoadingPage(
              controller: _homeController,
              onCompleted: () {
                if (!mounted) {
                  return;
                }
                setState(() => _isBootstrapped = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _ensureFirstLaunchCameraPermission();
                });
              },
            )
          : _isAdminMode
          ? AdminShell(
              selectedIndex: _adminSelectedIndex,
              onTabChanged: (index) {
                setState(() => _adminSelectedIndex = index);
              },
              body: _adminPages[_adminSelectedIndex],
            )
          : AppShell(
              selectedIndex: _selectedIndex,
              onTabChanged: (index) async {
                final isProfileTab = index == 4;
                final isReviewsTab = index == 3;

                if (isProfileTab || isReviewsTab) {
                  await _authController.restoreSession();
                }

                if ((isProfileTab || isReviewsTab) &&
                    !_authController.isAuthenticated) {
                  await _navigatorKey.currentState?.pushNamed('/login');
                  if (!mounted) {
                    return;
                  }
                  return;
                }

                setState(() => _selectedIndex = index);
              },
              body: _pages[_selectedIndex],
            ),
    );
  }

  Future<void> _ensureFirstLaunchCameraPermission() async {
    if (_isRequestingFirstCameraPermission) {
      return;
    }
    _isRequestingFirstCameraPermission = true;

    try {
      final prompted = await _storage.read(key: _cameraPermissionPromptedKey);
      if (prompted == '1') {
        return;
      }

      final status = await Permission.camera.status;
      if (status.isGranted || status.isLimited) {
        await _storage.write(key: _cameraPermissionPromptedKey, value: '1');
        return;
      }

      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }

      final shouldAskSystem =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Cho phép quyền camera'),
                content: const Text(
                  'Ứng dụng cần quyền camera để scan sản phẩm nhanh hơn.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Để sau'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Cho phép'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (shouldAskSystem) {
        final result = await Permission.camera.request();
        if (!context.mounted) {
          return;
        }

        if (result.isPermanentlyDenied) {
          if (!context.mounted) {
            return;
          }
          final shouldOpenSettings =
              await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Camera bị từ chối vĩnh viễn'),
                    content: const Text(
                      'Hãy mở cài đặt và cấp quyền camera để sử dụng tính năng scan.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Đóng'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Mở cài đặt'),
                      ),
                    ],
                  );
                },
              ) ??
              false;

          if (shouldOpenSettings) {
            await openAppSettings();
          }
        }
      }

      await _storage.write(key: _cameraPermissionPromptedKey, value: '1');
    } finally {
      _isRequestingFirstCameraPermission = false;
    }
  }
}
