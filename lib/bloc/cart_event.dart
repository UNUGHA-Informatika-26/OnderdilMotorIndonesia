/// Event yang bisa dikirim ke CartBloc.
abstract class CartEvent {
  const CartEvent();
}

class CartLoadRequested extends CartEvent {
  const CartLoadRequested();
}

class CartItemAdded extends CartEvent {
  const CartItemAdded({
    required this.partId,
    required this.name,
    required this.price,
    required this.stock,
  });
  final String partId;
  final String name;
  final double price;
  final int stock;
}

class CartItemIncremented extends CartEvent {
  const CartItemIncremented(this.partId);
  final String partId;
}

class CartItemDecremented extends CartEvent {
  const CartItemDecremented(this.partId);
  final String partId;
}

class CartItemRemoved extends CartEvent {
  const CartItemRemoved(this.partId);
  final String partId;
}

class CartCleared extends CartEvent {
  const CartCleared();
}

class CartLocalCleared extends CartEvent {
  const CartLocalCleared();
}