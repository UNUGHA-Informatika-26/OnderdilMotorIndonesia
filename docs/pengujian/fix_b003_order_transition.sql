-- ============================================================
-- Fix B-003: Validasi transisi status order di database
-- ============================================================
-- Masalah: Status order bisa diubah bebas oleh admin tanpa
-- validasi payment_status, sehingga:
--   1. Order bisa 'completed' sebelum pembayaran diverifikasi
--   2. Order verified bisa di-'cancelled' (hilang dari omset)
--   3. Order verified bisa mundur ke 'pending' (inkonsisten)
--
-- Solusi: BEFORE UPDATE trigger yang menolak transisi tidak valid.
-- Transisi yang diizinkan (UI hanya punya tombol Selesai & Dibatalkan):
--   pending  -> completed   HANYA JIKA payment_status = 'verified'
--   pending  -> cancelled   kapan saja (belum dibayar)
--   completed -> *          TIDAK BOLEH (final state)
--   cancelled -> *          TIDAK BOLEH (final state)
-- ============================================================

DROP TRIGGER IF EXISTS validate_order_transition ON public.orders;
DROP FUNCTION IF EXISTS public.validate_order_transition();

CREATE FUNCTION public.validate_order_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Abaikan jika status tidak berubah
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- completed hanya boleh dari pending dan jika pembayaran verified
  IF NEW.status = 'completed' THEN
    IF OLD.status IS DISTINCT FROM 'pending' THEN
      RAISE EXCEPTION 'Status "completed" hanya boleh dari "pending"';
    END IF;
    IF NEW.payment_status IS DISTINCT FROM 'verified' THEN
      RAISE EXCEPTION 'Status "completed" hanya boleh jika pembayaran sudah diverifikasi';
    END IF;
  END IF;

  -- cancelled hanya boleh dari pending (sebelum selesai)
  IF NEW.status = 'cancelled' THEN
    IF OLD.status IS DISTINCT FROM 'pending' THEN
      RAISE EXCEPTION 'Status "cancelled" hanya boleh dari "pending"';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER validate_order_transition
  BEFORE UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_order_transition();
