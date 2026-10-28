import { useMemo, useState } from 'react'

type Screen = 'login' | 'catalog' | 'cart' | 'history' | 'parts' | 'orders' | 'reports'
type IconName = 'search' | 'history' | 'cart' | 'logout' | 'home' | 'box' | 'receipt' | 'chart' | 'plus' | 'minus' | 'edit' | 'trash' | 'upload' | 'back' | 'check' | 'close' | 'bike' | 'user'

const photos = [
  'https://images.unsplash.com/photo-1770400770192-05b8b1cdb8fb?auto=format&fit=crop&w=500&q=80',
  'https://images.unsplash.com/photo-1525207106105-b340f7384b30?auto=format&fit=crop&w=500&q=80',
  'https://images.unsplash.com/photo-1785575152310-ea47b0e0f95d?auto=format&fit=crop&w=500&q=80',
  'https://images.unsplash.com/photo-1620223200930-2e719f329f07?auto=format&fit=crop&w=500&q=80',
]

const products = [
  { id: 1, name: 'Kampas Rem Depan', pn: '06455-K56-N01', price: 185000, stock: 12, photo: photos[0], category: 'Pengereman' },
  { id: 2, name: 'Gear Set Racing', pn: '23801-KYZ-901', price: 425000, stock: 6, photo: photos[1], category: 'Drivetrain' },
  { id: 3, name: 'Filter Oli OEM', pn: '15410-KVB-901', price: 48000, stock: 24, photo: photos[2], category: 'Mesin' },
  { id: 4, name: 'Velg Depan Sport', pn: '44650-K15-921', price: 890000, stock: 0, photo: photos[3], category: 'Roda' },
]

const rupiah = (n: number) => `Rp ${n.toLocaleString('id-ID')}`

function Icon({ name, size = 20 }: { name: IconName; size?: number }) {
  const paths: Record<IconName, React.ReactNode> = {
    search: <><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></>,
    history: <><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/></>,
    cart: <><path d="M3 4h2l2 11h10l2-7H6"/><circle cx="9" cy="20" r="1"/><circle cx="17" cy="20" r="1"/></>,
    logout: <><path d="M10 4H5v16h5M14 8l4 4-4 4M8 12h10"/></>,
    home: <><path d="m3 11 9-8 9 8"/><path d="M5 10v10h14V10M9 20v-6h6v6"/></>,
    box: <><path d="m4 7 8-4 8 4-8 4-8-4Z"/><path d="M4 7v10l8 4 8-4V7M12 11v10"/></>,
    receipt: <><path d="M6 3h12v18l-3-2-3 2-3-2-3 2V3Z"/><path d="M9 8h6M9 12h6"/></>,
    chart: <><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></>,
    plus: <path d="M12 5v14M5 12h14"/>,
    minus: <path d="M5 12h14"/>,
    edit: <><path d="m4 16-1 5 5-1L19 9l-4-4L4 16Z"/><path d="m13 7 4 4"/></>,
    trash: <><path d="M4 7h16M9 7V4h6v3M7 7l1 14h8l1-14"/></>,
    upload: <><path d="M12 16V4M7 9l5-5 5 5"/><path d="M5 15v5h14v-5"/></>,
    back: <><path d="m15 18-6-6 6-6"/><path d="M9 12h11"/></>,
    check: <path d="m5 12 4 4L19 6"/>,
    close: <path d="m6 6 12 12M18 6 6 18"/>,
    bike: <><circle cx="6" cy="17" r="4"/><circle cx="18" cy="17" r="4"/><path d="m6 17 4-8h5l3 8M9 12h7M10 9 8 6h3"/></>,
    user: <><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></>,
  }
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>
}

function Button({ children, onClick, variant = 'primary', disabled = false, icon }: { children: React.ReactNode; onClick?: () => void; variant?: 'primary'|'outline'|'danger'|'success'|'ghost'; disabled?: boolean; icon?: IconName }) {
  return <button className={`btn ${variant}`} onClick={onClick} disabled={disabled}>{icon && <Icon name={icon} size={18}/>}<span>{children}</span></button>
}

function Status({ children, kind = 'waiting' }: { children: React.ReactNode; kind?: 'waiting'|'success'|'danger'|'info' }) {
  return <span className={`status ${kind}`}>{children}</span>
}

function Header({ title, subtitle, onBack, actions, className = '', hideSubtitle = false }: { title: string; subtitle?: string; onBack?: () => void; actions?: React.ReactNode; className?: string; hideSubtitle?: boolean }) {
  return <header className={`topbar ${className}`}>{onBack && <button className="icon-btn" onClick={onBack} aria-label="Kembali"><Icon name="back"/></button>}<div className="top-title">{!hideSubtitle && <small>{subtitle}</small>}<strong>{title}</strong></div><div className="actions">{actions}</div></header>
}

function Field({ label, placeholder, type = 'text' }: { label: string; placeholder: string; type?: string }) {
  return <label className="field"><span>{label}</span><input type={type} placeholder={placeholder}/></label>
}

function Login({ onLogin }: { onLogin: (admin: boolean) => void }) {
  const [tab, setTab] = useState<'Masuk'|'Daftar'>('Masuk')
  return <main className="login-page">
    <div className="brand-mark"><Icon name="bike" size={44}/></div>
    <h1>O<span>M</span>I</h1>
    <p className="tagline">Onderdil Motor Indonesia</p>
    <div className="auth-card">
      <div className="tabs">{(['Masuk','Daftar'] as const).map(x => <button className={tab === x ? 'active' : ''} onClick={() => setTab(x)} key={x}>{x}</button>)}</div>
      {tab === 'Daftar' && <Field label="Nama lengkap" placeholder="Nama Anda"/>}
      <Field label="Email" placeholder="nama@email.com" type="email"/>
      <Field label="Password" placeholder="Minimal 8 karakter" type="password"/>
      <Button onClick={() => onLogin(false)}>{tab === 'Masuk' ? 'Masuk ke Akun' : 'Buat Akun'}</Button>
      <div className="divider"><span>atau akses demo</span></div>
      <Button variant="outline" icon="user" onClick={() => onLogin(true)}>Masuk sebagai Admin</Button>
    </div>
    <small className="copyright">OEM verified parts · Garansi resmi</small>
  </main>
}

function CustomerNav({ screen, go, cartCount }: { screen: Screen; go: (s: Screen) => void; cartCount: number }) {
  return <nav className="bottom-nav">
    <button className={screen === 'catalog' ? 'active':''} onClick={() => go('catalog')}><span className="nav-icon"><Icon name="home"/></span><span className="nav-label">Katalog</span></button>
    <button className={screen === 'history' ? 'active':''} onClick={() => go('history')}><span className="nav-icon"><Icon name="history"/></span><span className="nav-label">Riwayat</span></button>
    <button className={screen === 'cart' ? 'active':''} onClick={() => go('cart')}><span className="nav-icon"><Icon name="cart"/>{cartCount > 0 && <b>{cartCount}</b>}</span><span className="nav-label">Keranjang</span></button>
  </nav>
}

function Catalog({ cart, setCart, go, logout }: { cart: Record<number,number>; setCart: React.Dispatch<React.SetStateAction<Record<number,number>>>; go: (s: Screen)=>void; logout: ()=>void }) {
  const [q, setQ] = useState('')
  const [profileOpen, setProfileOpen] = useState(false)
  const [profileView, setProfileView] = useState<'menu'|'personal'|'address'|'security'>('menu')
  const closeProfile = () => { setProfileOpen(false); setProfileView('menu') }
  const list = products.filter(p => `${p.name} ${p.pn}`.toLowerCase().includes(q.toLowerCase()))
  return <main className="screen">
    <Header title="Halo, Andi" subtitle="Selamat datang kembali" actions={<button className="profile-trigger" onClick={() => setProfileOpen(true)} aria-label="Buka profil"><span>AP</span><i/></button>}/>
    <section className="content catalog-content">
      <div className="eyebrow">SPAREPART ORIGINAL</div><h2>Siap melaju lebih jauh.</h2>
      <div className="search"><Icon name="search"/><input value={q} onChange={e=>setQ(e.target.value)} placeholder="Cari nama atau part number..."/></div>
      <div className="section-head"><strong>Semua Produk</strong><span>{list.length} barang</span></div>
      <div className="product-grid">{list.map(p => <article className="product-card" key={p.id}>
        <div className="product-image"><img src={p.photo} alt={p.name}/>{p.stock === 0 && <span className="soldout">Habis</span>}</div>
        <div className="product-body"><span className="category">{p.category}</span><h3>{p.name}</h3><code>{p.pn}</code><strong className="price">{rupiah(p.price)}</strong><small className={p.stock === 0 ? 'no-stock':''}>{p.stock ? `Stok ${p.stock}` : 'Stok habis'}</small>
          <Button disabled={p.stock === 0} icon="plus" onClick={()=>setCart(c=>({...c,[p.id]:(c[p.id]||0)+1}))}>{cart[p.id] ? `${cart[p.id]} di keranjang` : 'Tambah'}</Button>
        </div>
      </article>)}</div>
    </section>
    <CustomerNav screen="catalog" go={go} cartCount={Object.values(cart).reduce((a,b)=>a+b,0)}/>
    {profileOpen && <div className="modal-backdrop" onMouseDown={closeProfile}>
      <div className="profile-sheet" onMouseDown={e => e.stopPropagation()}>
        <div className="sheet-handle"/>
        {profileView === 'menu' ? <>
          <div className="profile-identity">
            <div className="profile-avatar">AP</div>
            <div><h2>Andi Pratama</h2><p>andi.pratama@email.com</p><Status kind="success">Member Aktif</Status></div>
            <button className="icon-btn" onClick={closeProfile} aria-label="Tutup"><Icon name="close"/></button>
          </div>
          <div className="profile-menu">
            <button onClick={() => setProfileView('personal')}><span className="menu-icon"><Icon name="user"/></span><span><strong>Data Pribadi</strong><small>Nama, email, dan nomor telepon</small></span><b>›</b></button>
            <button onClick={() => setProfileView('address')}><span className="menu-icon"><Icon name="home"/></span><span><strong>Alamat Pengiriman</strong><small>Kelola alamat utama Anda</small></span><b>›</b></button>
            <button onClick={() => setProfileView('security')}><span className="menu-icon"><Icon name="check"/></span><span><strong>Keamanan Akun</strong><small>Password dan privasi akun</small></span><b>›</b></button>
          </div>
          <Button variant="danger" icon="logout" onClick={logout}>Keluar dari Akun</Button>
        </> : <>
          <div className="profile-layer-head">
            <button className="icon-btn" onClick={() => setProfileView('menu')} aria-label="Kembali"><Icon name="back"/></button>
            <div><small>PENGATURAN PROFIL</small><h2>{profileView === 'personal' ? 'Data Pribadi' : profileView === 'address' ? 'Alamat Pengiriman' : 'Keamanan Akun'}</h2></div>
            <button className="icon-btn" onClick={closeProfile} aria-label="Tutup"><Icon name="close"/></button>
          </div>
          {profileView === 'personal' && <div className="profile-form">
            <div className="avatar-editor"><div className="profile-avatar">AP</div><button>Ubah Foto</button></div>
            <Field label="Nama lengkap" placeholder="Andi Pratama"/>
            <Field label="Email" placeholder="andi.pratama@email.com" type="email"/>
            <Field label="Nomor telepon" placeholder="0812 3456 7890"/>
            <Button onClick={() => setProfileView('menu')}>Simpan Perubahan</Button>
          </div>}
          {profileView === 'address' && <div className="profile-form">
            <div className="address-badge"><span className="menu-icon"><Icon name="home"/></span><div><strong>Alamat Utama</strong><small>Digunakan saat checkout</small></div><Status kind="success">Aktif</Status></div>
            <Field label="Label alamat" placeholder="Rumah"/>
            <Field label="Nama penerima" placeholder="Andi Pratama"/>
            <Field label="Nomor telepon" placeholder="0812 3456 7890"/>
            <label className="field"><span>Alamat lengkap</span><textarea defaultValue="Jl. Merdeka No. 12, Sukajadi, Bandung, Jawa Barat 40162"/></label>
            <Button onClick={() => setProfileView('menu')}>Simpan Alamat</Button>
          </div>}
          {profileView === 'security' && <div className="profile-form">
            <div className="security-note"><span className="menu-icon"><Icon name="check"/></span><div><strong>Akun Anda terlindungi</strong><small>Terakhir mengubah password 3 bulan lalu</small></div></div>
            <Field label="Password saat ini" placeholder="Masukkan password saat ini" type="password"/>
            <Field label="Password baru" placeholder="Minimal 8 karakter" type="password"/>
            <Field label="Konfirmasi password" placeholder="Ulangi password baru" type="password"/>
            <p className="password-hint">Gunakan kombinasi huruf besar, angka, dan simbol untuk keamanan lebih baik.</p>
            <Button onClick={() => setProfileView('menu')}>Perbarui Password</Button>
          </div>}
        </>}
      </div>
    </div>}
  </main>
}

function Cart({ cart, setCart, go }: { cart: Record<number,number>; setCart: React.Dispatch<React.SetStateAction<Record<number,number>>>; go:(s:Screen)=>void }) {
  const items = products.filter(p=>cart[p.id])
  const total = items.reduce((s,p)=>s+p.price*cart[p.id],0)
  const step=(id:number,d:number)=>setCart(c=>{const n={...c,[id]:(c[id]||0)+d}; if(n[id]<=0) delete n[id]; return n})
  return <main className="screen">
    <Header title="Keranjang" onBack={()=>go('catalog')}/>
    <section className="content checkout-content">
      {items.length ? <>{items.map(p=><article className="cart-item" key={p.id}><img src={p.photo} alt=""/><div className="cart-copy"><strong>{p.name}</strong><small>{rupiah(p.price)} × {cart[p.id]}</small><b>{rupiah(p.price*cart[p.id])}</b></div><div className="stepper"><button onClick={()=>step(p.id,-1)}><Icon name="minus" size={15}/></button><span>{cart[p.id]}</span><button onClick={()=>step(p.id,1)}><Icon name="plus" size={15}/></button></div></article>)}
        <div className="form-section"><div className="section-head"><strong>Detail Pengiriman</strong><span>Wajib diisi</span></div><Field label="Nama penerima" placeholder="Andi Pratama"/><Field label="Nomor telepon" placeholder="08xxxxxxxxxx"/><label className="field"><span>Alamat lengkap</span><textarea placeholder="Jalan, nomor rumah, kecamatan, kota"/></label><label className="field"><span>Kurir pengiriman</span><select defaultValue="jne"><option value="jne">JNE Reguler · 2–3 hari</option><option>J&T Express · 2–3 hari</option><option>SiCepat BEST · 1–2 hari</option></select></label></div></> : <div className="empty"><div><Icon name="cart" size={42}/></div><h2>Keranjang masih kosong</h2><p>Temukan sparepart yang cocok untuk motor Anda.</p><Button onClick={()=>go('catalog')}>Lihat Katalog</Button></div>}
    </section>
    {items.length>0 && <div className="sticky-total"><div><small>Total bayar</small><strong>{rupiah(total+18000)}</strong></div><Button onClick={()=>go('history')}>Checkout</Button></div>}
  </main>
}

const orders = [
  { id:'ORD-240521-08', date:'21 Mei 2025', total:673000, status:'Menunggu', kind:'waiting' as const, paid:true },
  { id:'ORD-240418-21', date:'18 Apr 2025', total:425000, status:'Selesai', kind:'success' as const, paid:true },
  { id:'ORD-240310-03', date:'10 Mar 2025', total:233000, status:'Dibatalkan', kind:'danger' as const, paid:false },
]

function History({ go }: { go:(s:Screen)=>void }) {
  const [uploaded,setUploaded]=useState(false)
  return <main className="screen"><Header title="Riwayat Pesanan" hideSubtitle/>
    <section className="content order-list">{orders.map((o,i)=><article className="order-card" key={o.id}><div className="order-top"><div><small>#{o.id}</small><strong>{o.date}</strong></div><Status kind={o.kind}>{o.status}</Status></div><div className="order-total"><span>Total pembayaran</span><strong>{rupiah(o.total)}</strong></div>{i===0 && <div className="payment"><div className="payment-status"><span className={uploaded?'dot success-dot':'dot'}/><div><strong>{uploaded?'Bukti terkirim':'Menunggu bukti bayar'}</strong><small>{uploaded?'Akan diverifikasi admin':'Transfer sebelum 22 Mei, 18:30'}</small></div></div><Button variant={uploaded?'outline':'primary'} icon={uploaded?'check':'upload'} onClick={()=>setUploaded(true)}>{uploaded?'Bukti Terunggah':'Upload Bukti Transfer'}</Button></div>}</article>)}</section>
    <CustomerNav screen="history" go={go} cartCount={2}/>
  </main>
}

function AdminNav({ screen, go }: { screen:Screen; go:(s:Screen)=>void }) {
  return <nav className="bottom-nav admin-nav"><button className={screen==='parts'?'active':''} onClick={()=>go('parts')}><span className="nav-icon"><Icon name="box"/></span><span className="nav-label">Sparepart</span></button><button className={screen==='orders'?'active':''} onClick={()=>go('orders')}><span className="nav-icon"><Icon name="receipt"/></span><span className="nav-label">Pesanan</span></button><button className={screen==='reports'?'active':''} onClick={()=>go('reports')}><span className="nav-icon"><Icon name="chart"/></span><span className="nav-label">Laporan</span></button></nav>
}

function Parts({ go, logout }: { go:(s:Screen)=>void; logout:()=>void }) {
  const [modal,setModal]=useState(false)
  return <main className="screen"><Header title="Panel Admin" hideSubtitle className="parts-admin-header" actions={<button className="icon-btn admin-logout" onClick={logout}><Icon name="logout"/></button>}/>
    <section className="content admin-content"><div className="admin-heading"><div><div className="eyebrow">INVENTORI</div><h2>Daftar Sparepart</h2></div><button className="fab" onClick={()=>setModal(true)}><Icon name="plus"/><span>Tambah</span></button></div>
      <div className="inventory">{products.map(p=><article className="inventory-row" key={p.id}><img src={p.photo} alt=""/><div><strong>{p.name}</strong><code>{p.pn}</code><span><b>{rupiah(p.price)}</b> · Stok {p.stock}</span></div><div className="row-actions"><button onClick={()=>setModal(true)}><Icon name="edit" size={17}/></button><button className="delete"><Icon name="trash" size={17}/></button></div></article>)}</div>
    </section><AdminNav screen="parts" go={go}/>
    {modal&&<div className="modal-backdrop" onMouseDown={()=>setModal(false)}><div className="modal" onMouseDown={e=>e.stopPropagation()}><div className="modal-head"><div><small>INVENTORI</small><h2>Tambah Sparepart</h2></div><button className="icon-btn" onClick={()=>setModal(false)}><Icon name="close"/></button></div><button className="photo-upload"><Icon name="upload"/><span>Unggah foto produk</span><small>JPG atau PNG, maks. 2 MB</small></button><div className="form-grid"><Field label="Nama sparepart" placeholder="Contoh: Kampas Rem"/><Field label="Part number (PN)" placeholder="00000-XXX-000"/><Field label="Kategori" placeholder="Mesin"/><Field label="Harga" placeholder="Rp 0"/><Field label="Stok" placeholder="0"/></div><Button onClick={()=>setModal(false)}>Simpan Sparepart</Button></div></div>}
  </main>
}

function AdminOrders({ go }: { go:(s:Screen)=>void }) {
  const [handled,setHandled]=useState<Record<string,string>>({})
  return <main className="screen"><Header title="Kelola Pesanan" hideSubtitle/><section className="content order-list admin-orders">{orders.slice(0,2).map((o,i)=><article className="order-card" key={o.id}><div className="order-top"><div><small>#{o.id}</small><strong>{i?'Sinta Maharani':'Andi Pratama'}</strong><span>{o.date} · {i?'3':'2'} item</span></div><Status kind={handled[o.id]==='Tolak'?'danger':handled[o.id]==='Verifikasi'?'success':o.kind}>{handled[o.id]||o.status}</Status></div><div className="order-total"><span>Total pembayaran</span><strong>{rupiah(o.total)}</strong></div><button className="proof"><div className="proof-icon"><Icon name="receipt"/></div><div><strong>Bukti transfer.jpg</strong><small>Diunggah 12 menit lalu</small></div><span>Preview</span></button>{i===0&&!handled[o.id]&&<div className="verify-actions"><Button variant="danger" icon="close" onClick={()=>setHandled(x=>({...x,[o.id]:'Tolak'}))}>Tolak</Button><Button variant="success" icon="check" onClick={()=>setHandled(x=>({...x,[o.id]:'Verifikasi'}))}>Verifikasi</Button></div>}</article>)}</section><AdminNav screen="orders" go={go}/></main>
}

function Reports({ go }: { go:(s:Screen)=>void }) {
  const [modal,setModal]=useState(false)
  return <main className="screen"><Header title="Laporan Penjualan" hideSubtitle/><section className="content report-content"><div className="filters"><label><span>Periode</span><input type="date" defaultValue="2025-05-01"/></label><label><span>Status</span><select><option>Semua status</option><option>Selesai</option><option>Menunggu</option></select></label></div><div className="metrics"><article><span className="metric-icon"><Icon name="receipt"/></span><small>Total Pesanan</small><strong>128</strong><em>+12% bulan ini</em></article><article><span className="metric-icon green"><Icon name="chart"/></span><small>Omset Sukses</small><strong>Rp 24,8jt</strong><em>+8,4% bulan ini</em></article></div><div className="section-head"><strong>Transaksi Terbaru</strong><button className="text-btn" onClick={()=>setModal(true)}>Export</button></div><div className="transactions">{orders.map(o=><article key={o.id}><div><strong>#{o.id}</strong><small>{o.date}</small></div><div><b>{rupiah(o.total)}</b><Status kind={o.kind}>{o.status}</Status></div></article>)}</div></section><AdminNav screen="reports" go={go}/>{modal&&<div className="modal-backdrop" onClick={()=>setModal(false)}><div className="export-sheet" onClick={e=>e.stopPropagation()}><div className="sheet-handle"/><h2>Export Laporan</h2><p>Pilih format untuk laporan periode ini.</p><Button icon="upload" onClick={()=>setModal(false)}>Export CSV</Button><Button variant="outline" onClick={()=>setModal(false)}>Salin ke Clipboard</Button></div></div>}</main>
}

export default function App() {
  const [screen,setScreen]=useState<Screen>('login')
  const [cart,setCart]=useState<Record<number,number>>({})
  const isAdmin = useMemo(()=>['parts','orders','reports'].includes(screen),[screen])
  const logout=()=>setScreen('login')
  return <div className="app-shell"><div className={`phone ${isAdmin?'admin-mode':''}`}>
    {screen==='login'&&<Login onLogin={admin=>setScreen(admin?'parts':'catalog')}/>}
    {screen==='catalog'&&<Catalog cart={cart} setCart={setCart} go={setScreen} logout={logout}/>}
    {screen==='cart'&&<Cart cart={cart} setCart={setCart} go={setScreen}/>}
    {screen==='history'&&<History go={setScreen}/>}
    {screen==='parts'&&<Parts go={setScreen} logout={logout}/>}
    {screen==='orders'&&<AdminOrders go={setScreen}/>}
    {screen==='reports'&&<Reports go={setScreen}/>}
  </div></div>
}
