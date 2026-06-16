import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../data/datasources/shop_remote_data_source.dart';
import '../manager/auth_controller.dart';
import '../models/scan_search_payload.dart';
import '../widgets/cart_icon_bubble.dart';
import '../widgets/chat_icon_bubble.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.authController,
    required this.cartCountListenable,
    this.chatCountListenable,
    this.onOpenCart,
    this.onOpenChat,
    this.onOpenShopChat,
    this.onSearchResult,
    this.onNavigateToHome,
  });

  final AuthController authController;
  final ValueListenable<int> cartCountListenable;
  final ValueListenable<int>? chatCountListenable;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenShopChat;
  final ValueChanged<ScanSearchPayload>? onSearchResult;
  final VoidCallback? onNavigateToHome;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final ShopRemoteDataSource _remote = ShopRemoteDataSource();

  CameraController? _cameraController;
  Timer? _focusIndicatorTimer;
  String? _selectedImagePath;
  bool _isCameraReady = false;
  bool _isCameraInitializing = false;
  bool _isCapturing = false;
  bool _isSearching = false;
  bool _isFlashEnabled = false;
  bool _isFlashSupported = true;
  Offset? _focusIndicatorOffset;
  Size _cameraAreaSize = Size.zero;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusIndicatorTimer?.cancel();
    unawaited(_disposeCameraController());
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeCameraController());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: () async {
        setState(() {
          _selectedImagePath = null;
        });
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _buildTopBar(context),
          const SizedBox(height: 18),
          _buildSectionHeader(context, 'TÌM KIẾM BẰNG HÌNH ẢNH', ''),
          const SizedBox(height: 12),
          _buildCameraArea(context),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  context,
                  icon: Icons.photo_library_outlined,
                  label: 'THƯ VIỆN',
                  onTap: _isBusy ? null : _pickFromGallery,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  context,
                  icon: Icons.camera_alt_rounded,
                  label: 'CHỤP ẢNH',
                  highlighted: true,
                  onTap: _isBusy ? null : _captureFromLiveCamera,
                ),
              ),
            ],
          ),
          if (_isBusy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 8),
            Text(
              _isCapturing
                  ? 'Đang chụp ảnh...'
                  : 'Đang phân tích và tìm sản phẩm từ hình ảnh...',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onNavigateToHome,
          child: Text(
            'SHUTTLE_X',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.primaryContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const Spacer(),
        if (widget.chatCountListenable != null)
          ValueListenableBuilder<int>(
            valueListenable: widget.chatCountListenable!,
            builder: (_, count, __) {
              return ChatIconBubble(
                count: count,
                onTap: widget.onOpenShopChat,
                icon: Icons.chat_rounded,
              );
            },
          )
        else
          ChatIconBubble(
            count: 0,
            onTap: widget.onOpenShopChat,
            icon: Icons.chat_rounded,
          ),
        const SizedBox(width: 6),
        ChatIconBubble(count: 0, onTap: widget.onOpenChat),
        const SizedBox(width: 10),
        ValueListenableBuilder<int>(
          valueListenable: widget.cartCountListenable,
          builder: (_, count, __) {
            return CartIconBubble(count: count, onTap: widget.onOpenCart);
          },
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.surfaceContainerHighest,
          backgroundImage: widget.authController.userProfile?.avatar != null
              ? NetworkImage(widget.authController.userProfile!.avatar!)
              : null,
          child: widget.authController.userProfile?.avatar == null
              ? const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20)
              : null,
        ),
      ],
    );
  }



  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String action,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontStyle: FontStyle.italic,
              fontSize: 23,
            ),
          ),
        ),
        if (action.isNotEmpty)
          Text(
            action,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.primaryContainer,
              fontSize: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildCameraArea(BuildContext context) {
    final controller = _cameraController;

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _cameraAreaSize = constraints.biggest;
                  if (_isCameraReady &&
                      controller != null &&
                      controller.value.isInitialized) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: _isBusy ? null : _onPreviewTap,
                      child: CameraPreview(controller),
                    );
                  }
                  return _buildCameraFallback(context);
                },
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.75),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          if (_focusIndicatorOffset != null)
            Positioned(
              left: _focusIndicatorOffset!.dx - 22,
              top: _focusIndicatorOffset!.dy - 22,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: 1,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.secondary, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(top: 16, right: 16, child: _buildCameraToolRow(context)),
          if (_selectedImagePath != null)
            Positioned(
              right: 18,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest.withValues(
                    alpha: 0.78,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Ảnh đã chọn',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraToolRow(BuildContext context) {
    return Row(
      children: [
        if (_isFlashSupported)
          _cameraToolButton(
            icon: _isFlashEnabled
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            onTap: _isBusy ? null : _toggleFlash,
          ),
      ],
    );
  }

  Widget _cameraToolButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.82),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }

  Widget _buildCameraFallback(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceContainerHighest.withValues(alpha: 0.55),
            AppColors.surfaceContainer.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCameraInitializing)
                const CircularProgressIndicator(color: AppColors.secondary)
              else
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 46,
                  color: AppColors.textSecondary,
                ),
              const SizedBox(height: 10),
              Text(
                _cameraError ?? 'Đang khởi tạo camera...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (!_isCameraInitializing) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isBusy ? null : _initCamera,
                  child: const Text('Thử lại camera'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool highlighted = false,
  }) {
    final foreground = highlighted
        ? AppColors.onPrimaryContainer
        : AppColors.textPrimary;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: highlighted
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerLow,
          border: Border.all(
            color: highlighted
                ? AppColors.primaryContainer
                : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1920,
    );
    if (file == null) {
      return;
    }

    setState(() => _selectedImagePath = file.path);
    await _searchWithImage(file.path);
  }

  Future<void> _captureFromLiveCamera() async {
    final controller = _cameraController;
    if (!_isCameraReady ||
        controller == null ||
        !controller.value.isInitialized) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Camera chưa sẵn sàng.')));
      return;
    }

    setState(() => _isCapturing = true);
    XFile? capture;
    try {
      capture = await controller.takePicture();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..showSnackBar(SnackBar(content: Text('Không thể chụp ảnh. $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }

    final captured = capture;
    if (captured == null || !mounted) {
      return;
    }

    try {
      await controller.pausePreview();
    } catch (_) {
      // Ignore pause failures on devices that don't support pause/resume.
    }

    final approved = await _showCameraPreviewAndConfirm(captured.path);

    try {
      await controller.resumePreview();
    } catch (_) {
      // Keep going; capture flow is still valid.
    }

    if (!mounted) {
      return;
    }

    if (approved == true) {
      setState(() => _selectedImagePath = captured.path);
      await _searchWithImage(captured.path);
    }
  }

  Future<bool?> _showCameraPreviewAndConfirm(String imagePath) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.outlineVariant),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xác nhận ảnh vừa chụp',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.file(File(imagePath), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Chụp lại',
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Sử dụng ảnh này',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          foregroundColor: AppColors.onPrimaryContainer,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _searchWithImage(String path) async {
    setState(() => _isSearching = true);
    try {
      await widget.authController.restoreSession();
      final token = widget.authController.session?.token;
      if (kDebugMode) {
        final sourceFile = File(path);
        debugPrint(
          '[ImageSearch][INPUT] original=$path '
          'originalBytes=${sourceFile.existsSync() ? sourceFile.lengthSync() : -1} '
          'hasToken=${token != null && token.isNotEmpty}',
        );
      }
      final page = await _remote.searchProductsByImage(
        imagePath: path,
        accessToken: token,
      );
      if (!mounted) {
        return;
      }
      widget.onSearchResult?.call(
        ScanSearchPayload(
          products: page.items.map((e) => e.toEntity()).toList(),
          imagePath: path,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Không thể tìm kiếm bằng hình ảnh. $e')),
        );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  bool get _isBusy => _isSearching || _isCapturing;

  void _onPreviewTap(TapDownDetails details) {
    final controller = _cameraController;
    if (!_isCameraReady ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final position = details.localPosition;
    if (!mounted) {
      return;
    }

    setState(() {
      _focusIndicatorOffset = position;
    });

    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) {
        return;
      }
      setState(() => _focusIndicatorOffset = null);
    });

    final width = _cameraAreaSize.width <= 0 ? 1 : _cameraAreaSize.width;
    final height = _cameraAreaSize.height <= 0 ? 1 : _cameraAreaSize.height;

    final focusPoint = Offset(
      (position.dx / width).clamp(0.0, 1.0),
      (position.dy / height).clamp(0.0, 1.0),
    );

    controller.setFocusPoint(focusPoint);
    controller.setExposurePoint(focusPoint);
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (!_isCameraReady ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final next = !_isFlashEnabled;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) {
        return;
      }
      setState(() => _isFlashEnabled = next);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFlashSupported = false;
        _isFlashEnabled = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Thiết bị không hỗ trợ flash.')),
        );
    }
  }

  Future<void> _initCamera() async {
    if (_isCameraInitializing) {
      return;
    }
    if (_cameraController?.value.isInitialized == true) {
      return;
    }

    setState(() {
      _isCameraInitializing = true;
      _isCameraReady = false;
      _cameraError = null;
    });

    CameraController? nextController;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Thiết bị không có camera.');
      }

      final backCamera = cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .cast<CameraDescription?>()
          .firstWhere((c) => c != null, orElse: () => null);
      final selected = backCamera ?? cameras.first;

      nextController = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await nextController.initialize();
      try {
        await nextController.setFlashMode(FlashMode.off);
        _isFlashSupported = true;
      } catch (_) {
        _isFlashSupported = false;
      }

      if (!mounted) {
        await nextController.dispose();
        return;
      }

      final old = _cameraController;
      _cameraController = nextController;
      _isCameraReady = true;
      _isFlashEnabled = false;
      _cameraError = null;
      nextController = null;
      await old?.dispose();
    } catch (e) {
      _isCameraReady = false;
      _cameraError = 'Khong the mo camera. Hay cap quyen camera trong Android.';
    } finally {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
      await nextController?.dispose();
    }
  }

  Future<void> _disposeCameraController() async {
    final controller = _cameraController;
    _cameraController = null;
    _isCameraReady = false;
    if (controller != null) {
      await controller.dispose();
    }
  }
}
