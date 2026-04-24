import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../domain/entities/home_feed_entity.dart';
import '../../domain/entities/promotion_entity.dart';
import '../../domain/usecases/get_home_data_usecase.dart';
import '../../data/datasources/promotion_remote_data_source.dart';

class HomeController extends ChangeNotifier {
  HomeController(this._getHomeDataUseCase);

  final GetHomeDataUseCase _getHomeDataUseCase;
  final PromotionRemoteDataSource _promotionRemoteDataSource = PromotionRemoteDataSource();

  bool isLoading = true;
  bool isSyncing = false;
  String? syncWarning;
  String? error;
  HomeFeedEntity? feed;
  List<PromotionEntity> promotions = [];
  StreamSubscription<HomeFeedEntity>? _subscription;

  Future<void> load() async {
    final completer = Completer<void>();

    isLoading = feed == null;
    isSyncing = true;
    syncWarning = null;
    error = null;
    notifyListeners();

    await _subscription?.cancel();
    
    // Fetch promotions in parallel or before
    _fetchPromotions();

    _subscription = _getHomeDataUseCase().listen(
      (data) {
        feed = data;
        isLoading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object e) {
        if (feed == null) {
          error = e.toString();
          isLoading = false;
        } else {
          syncWarning =
              'Không thể cập nhật dữ liệu mới. Đang hiển thị dữ liệu offline.';
        }
        isSyncing = false;
        notifyListeners();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onDone: () {
        isSyncing = false;
        notifyListeners();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: false,
    );

    return completer.future;
  }
  
  Future<void> _fetchPromotions() async {
    try {
      final list = await _promotionRemoteDataSource.getActivePromotions();
      promotions = list.take(3).toList();
      notifyListeners();
    } catch (e, stack) {
      // ignore: avoid_print
      print('>>> PROMOTION FETCH ERROR: $e\n$stack');
      // Ignore promotion fetch errors silently so it doesn't block home page
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
