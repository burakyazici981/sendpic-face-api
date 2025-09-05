import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'supabase_auth_service.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final SupabaseAuthService _authService = SupabaseAuthService();
  
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  
  // Token packages
  static const Map<String, Map<String, dynamic>> tokenPackages = {
    'tokens_100': {
      'tokens': 100,
      'price': 0.99,
      'title': '100 Tokens',
      'description': 'Send 100 photos or 50 videos',
    },
    'tokens_500': {
      'tokens': 500,
      'price': 4.99,
      'title': '500 Tokens',
      'description': 'Send 500 photos or 250 videos',
    },
    'tokens_1000': {
      'tokens': 1000,
      'price': 8.99,
      'title': '1000 Tokens',
      'description': 'Send 1000 photos or 500 videos',
    },
    'tokens_2500': {
      'tokens': 2500,
      'price': 19.99,
      'title': '2500 Tokens',
      'description': 'Send 2500 photos or 1250 videos',
    },
    'tokens_5000': {
      'tokens': 5000,
      'price': 34.99,
      'title': '5000 Tokens',
      'description': 'Send 5000 photos or 2500 videos',
    },
  };
  
  // Initialize payment service
  Future<bool> initialize() async {
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      
      if (!_isAvailable) {
        print('In-app purchases not available');
        return false;
      }
      
      // Set up purchase listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription.cancel(),
        onError: (error) => print('Purchase stream error: $error'),
      );
      
      // Load products
      await _loadProducts();
      
      // Platform-specific setup
      if (Platform.isIOS) {
        await _setupIOS();
      } else if (Platform.isAndroid) {
        await _setupAndroid();
      }
      
      print('Payment service initialized successfully');
      return true;
    } catch (e) {
      print('Error initializing payment service: $e');
      return false;
    }
  }
  
  // Setup iOS specific configurations
  Future<void> _setupIOS() async {
    try {
      final InAppPurchaseStoreKitPlatformAddition iosAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      
      await iosAddition.setDelegate(ExamplePaymentQueueDelegate());
    } catch (e) {
      print('Error setting up iOS: $e');
    }
  }
  
  // Setup Android specific configurations
  Future<void> _setupAndroid() async {
    try {
      final InAppPurchaseAndroidPlatformAddition androidAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      
      await androidAddition.enablePendingPurchases();
    } catch (e) {
      print('Error setting up Android: $e');
    }
  }
  
  // Load available products
  Future<void> _loadProducts() async {
    try {
      final Set<String> productIds = tokenPackages.keys.toSet();
      
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }
      
      _products = response.productDetails;
      print('Loaded ${_products.length} products');
    } catch (e) {
      print('Error loading products: $e');
    }
  }
  
  // Get available token packages
  List<Map<String, dynamic>> getTokenPackages() {
    return _products.map((product) {
      final packageInfo = tokenPackages[product.id] ?? {};
      return {
        'id': product.id,
        'title': product.title,
        'description': product.description,
        'price': product.price,
        'tokens': packageInfo['tokens'] ?? 0,
        'productDetails': product,
      };
    }).toList();
  }
  
  // Purchase tokens
  Future<bool> purchaseTokens(String productId) async {
    try {
      if (!_isAvailable) {
        throw Exception('In-app purchases not available');
      }
      
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found'),
      );
      
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: user.id,
      );
      
      final bool success = await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
      );
      
      return success;
    } catch (e) {
      print('Error purchasing tokens: $e');
      return false;
    }
  }
  
  // Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _handlePurchase(purchaseDetails);
    }
  }
  
  // Handle individual purchase
  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    try {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        // Verify purchase and add tokens
        await _verifyAndProcessPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        print('Purchase canceled');
      }
      
      // Complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    } catch (e) {
      print('Error handling purchase: $e');
    }
  }
  
  // Verify and process purchase
  Future<void> _verifyAndProcessPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Get token amount for this product
      final packageInfo = tokenPackages[purchaseDetails.productID];
      if (packageInfo == null) {
        throw Exception('Unknown product');
      }
      
      final int tokenAmount = packageInfo['tokens'];
      
      // Add tokens to user account
      final success = await _authService.updateUserTokens({
        'photo_tokens': tokenAmount,
      });
      
      if (success) {
        print('Successfully added $tokenAmount tokens to user account');
        
        // Record transaction in database
        await _recordTransaction(
          userId: user.id,
          productId: purchaseDetails.productID,
          tokenAmount: tokenAmount,
          transactionId: purchaseDetails.purchaseID ?? '',
          verificationData: purchaseDetails.verificationData.localVerificationData,
        );
      } else {
        throw Exception('Failed to add tokens to user account');
      }
    } catch (e) {
      print('Error verifying purchase: $e');
      rethrow;
    }
  }
  
  // Record transaction in database
  Future<void> _recordTransaction({
    required String userId,
    required String productId,
    required int tokenAmount,
    required String transactionId,
    required String verificationData,
  }) async {
    try {
      // This would typically be done through your backend API
      // For now, we'll just log it
      print('Recording transaction: $userId, $productId, $tokenAmount tokens');
      
      // TODO: Implement actual transaction recording in Supabase
      // await _supabaseClient.from('token_transactions').insert({
      //   'user_id': userId,
      //   'product_id': productId,
      //   'token_amount': tokenAmount,
      //   'transaction_id': transactionId,
      //   'verification_data': verificationData,
      //   'status': 'completed',
      // });
    } catch (e) {
      print('Error recording transaction: $e');
    }
  }
  
  // Restore purchases
  Future<void> restorePurchases() async {
    try {
      if (!_isAvailable) {
        throw Exception('In-app purchases not available');
      }
      
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Error restoring purchases: $e');
      rethrow;
    }
  }
  
  // Check if payment service is available
  bool get isAvailable => _isAvailable;
  
  // Get products
  List<ProductDetails> get products => _products;
  
  // Dispose
  void dispose() {
    _subscription.cancel();
  }
}

// iOS Payment Queue Delegate
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}