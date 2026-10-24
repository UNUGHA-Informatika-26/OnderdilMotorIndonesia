import 'dart:async';
import '../cart_helper.dart';
import 'cart_event.dart';
import 'cart_state.dart';

/// CartBloc — menangani state keranjang belanja.
///
/// Pola BLoC: Event → BLoC (StreamController) → State → UI (StreamBuilder)
/// CartModel tetap sebagai data layer (sync ke Supabase).
class CartBloc {
  CartBloc() {
    _eventController.stream.listen(_mapEventToState);
  }

  final CartModel _cart = CartModel.instance;

  // Event sink: UI mengirim event via sink
  final _eventController = StreamController<CartEvent>.broadcast();
  StreamSink<CartEvent> get events => _eventController.sink;

  // State stream: UI mendengarkan via StreamBuilder
  final _stateController = StreamController<CartState>.broadcast();
  Stream<CartState> get state => _stateController.stream;

  CartState _currentState = CartInitial(); // ❌ Hapus 'const'
  CartState get currentState => _currentState;

  void _emit(CartState state) {
    _currentState = state;
    _stateController.add(state);
  }

  Future<void> _mapEventToState(CartEvent event) async {
    if (event is CartLoadRequested) {
      _emit(CartLoading()); // ❌ Hapus 'const'
      await _cart.loadCartFromDatabase();
      _emitLoaded();
    } else if (event is CartItemAdded) {
      await _cart.add(
        partId: event.partId,
        name: event.name,
        price: event.price,
        stock: event.stock,
      );
      _emitLoaded();
    } else if (event is CartItemIncremented) {
      await _cart.increment(event.partId);
      _emitLoaded();
    } else if (event is CartItemDecremented) {
      await _cart.decrement(event.partId);
      _emitLoaded();
    } else if (event is CartItemRemoved) {
      await _cart.remove(event.partId);
      _emitLoaded();
    } else if (event is CartCleared) {
      await _cart.clear();
      _emitLoaded();
    } else if (event is CartLocalCleared) {
      _cart.clearLocal();
      _emitLoaded();
    }
  }

  void _emitLoaded() {
    _emit(CartLoaded(
      items: _cart.items,
      totalPrice: _cart.totalPrice,
      totalCount: _cart.totalCount,
      isEmpty: _cart.isEmpty,
      isLoading: _cart.isLoading,
    ));
  }

  void dispose() {
    _eventController.close();
    _stateController.close();
  }
}