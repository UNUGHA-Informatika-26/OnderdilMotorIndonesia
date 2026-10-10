-- ==============================================================================
-- FASE 2: SQL SCHEMA & FUNCTIONS UPDATE (Supabase)
-- ==============================================================================

-- 1. TABEL CART ITEMS (Keranjang Belanja Tersimpan Permanen di Database)
create table if not exists public.cart_items (
    id uuid default gen_random_uuid() primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    part_id uuid not null references public.parts(id) on delete cascade,
    quantity int not null check (quantity > 0),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(user_id, part_id)
);

-- RLS untuk cart_items
alter table public.cart_items enable row level security;

create policy "Users can view their own cart items"
    on public.cart_items for select
    using (auth.uid() = user_id);

create policy "Users can insert into their own cart"
    on public.cart_items for insert
    with check (auth.uid() = user_id);

create policy "Users can update their own cart items"
    on public.cart_items for update
    using (auth.uid() = user_id);

create policy "Users can delete their own cart items"
    on public.cart_items for delete
    using (auth.uid() = user_id);

-- Realtime publication for cart_items
alter publication supabase_realtime add table public.cart_items;


-- 2. ROLE & PERMISSION (Admin Penuh vs Warehouse / Staff Gudang)
-- Role yang valid: 'customer', 'warehouse', 'admin'
-- Contoh cara ubah role staff:
-- update public.profiles set role = 'warehouse' where username = 'nama_staff';
-- update public.profiles set role = 'admin' where username = 'super_admin';

-- RLS Rule Parts Update:
-- Warehouse staff hanya boleh mengupdate stock, sedangkan admin penuh boleh ubah harga/nama/hapus.
-- (Bila RLS parts sudah ada, pastikan role 'admin' & 'warehouse' diizinkan select & update).
create policy "Staff warehouse and admin can view and update parts stock"
    on public.parts for update
    using (
        exists (
            select 1 from public.profiles
            where id = auth.uid() and role in ('admin', 'warehouse')
        )
    );

create policy "Only full admin can insert parts"
    on public.parts for insert
    with check (
        exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'admin'
        )
    );

create policy "Only full admin can delete parts"
    on public.parts for delete
    using (
        exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'admin'
        )
    );

-- Orders: Warehouse dan Admin dapat melihat seluruh pesanan dan update status pesanan
create policy "Staff warehouse and admin can view all orders"
    on public.orders for select
    using (
        exists (
            select 1 from public.profiles
            where id = auth.uid() and role in ('admin', 'warehouse')
        )
    );

create policy "Staff warehouse and admin can update order status"
    on public.orders for update
    using (
        exists (
            select 1 from public.profiles
            where id = auth.uid() and role in ('admin', 'warehouse')
        )
    );
