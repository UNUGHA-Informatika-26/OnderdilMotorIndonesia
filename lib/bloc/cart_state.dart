import '../cart_helper.dart';

/// State yang di-emit oleh CartBloc.
abstract class CartState {}

class CartInitial extends CartState {}

class CartLoading extends CartState {}

class CartLoaded extends CartState {
  CartLoaded({
    required this.items,
    required this.totalPrice,
    required this.totalCount,
    required this.isEmpty,
    this.isLoading = false,
  });

  final List<CartItem> items;
  final double totalPrice;
  final int totalCount;
  final bool isEmpty;
  final bool isLoading;

  /// Harga barang saja (tanpa ongkos kirim).
  double get subtotal => totalPrice;
}

class CartError extends CartState {
  CartError(this.message);
  final String message;
}