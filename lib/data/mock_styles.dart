import '../models/store_model.dart';
  
// ==========================================
// MOCK DATA: Stores
// ==========================================
final List<StoreModel> mockStores = [
  StoreModel(
    id: 'zara',
    name: 'ZARA',
    url: 'https://zara.com',
    description: 'Latest trends in clothing for women, men & kids.',
    logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/f/fd/Zara_Logo.svg', 
    // Using a placeholder image for demo if SVG not supported directly in NetworkImage without flutter_svg
    // Better to use a JPG/PNG for simplicity in prototype
    // logoUrl: 'https://logowik.com/content/uploads/images/zara-new-20203212.jpg',
  ),
  StoreModel(
    id: 'hm',
    name: 'H&M',
    url: 'https://hm.com',
    description: 'Fashion and quality at the best price.',
  ),
  StoreModel(
    id: 'massimo',
    name: 'Massimo Dutti',
    url: 'https://massimodutti.com',
    description: 'Elegant and universal style.',
  ),
  StoreModel(
    id: 'mango',
    name: 'MANGO',
    url: 'https://mango.com',
    description: 'Mediterranean style and culture.',
  ),
  StoreModel(
    id: 'nike',
    name: 'Nike',
    url: 'https://nike.com',
    description: 'Just Do It.',
  ),
  StoreModel(
    id: 'adidas',
    name: 'Adidas',
    url: 'https://adidas.com',
    description: 'Impossible is Nothing.',
  ),
  StoreModel(
    id: 'farfetch',
    name: 'Farfetch',
    url: 'https://farfetch.com',
    description: 'The world\'s greatest selection of luxury.',
  ),
  StoreModel(
    id: 'asos',
    name: 'ASOS',
    url: 'https://asos.com',
    description: 'Discover the latest fashion trends.',
  ),
];

class StyleInspiration {
  final String imageUrl;
  final String title;
  final String category;
  final List<String> tags;

  const StyleInspiration({
    required this.imageUrl,
    required this.title,
    required this.category,
    required this.tags,
  });
}

// Unsplash IDs for variety
// Men
const _mClassic = 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=1000&auto=format&fit=crop';
const _mBusiness = 'https://images.unsplash.com/photo-1594938298603-c8148c472f8ea3fd?q=80&w=1000&auto=format&fit=crop';
const _mCasual = 'https://images.unsplash.com/photo-1516826957135-700dedea698c?q=80&w=1000&auto=format&fit=crop';
const _mStreet = 'https://images.unsplash.com/photo-1516257984-b1b4d8c923362a74?q=80&w=1000&auto=format&fit=crop';
const _mSport = 'https://images.unsplash.com/photo-1571945153262-cb4cfce3b4e2?q=80&w=1000&auto=format&fit=crop';
const _mMin = 'https://images.unsplash.com/photo-1487222477894-8943e31ef7b2?q=80&w=1000&auto=format&fit=crop';
const _mWork = 'https://images.unsplash.com/photo-1504593811423-6dd665756598?q=80&w=1000&auto=format&fit=crop';
const _mPrep = 'https://images.unsplash.com/photo-1617137984095-74e4e5e3613f?q=80&w=1000&auto=format&fit=crop';
const _mGue = 'https://images.unsplash.com/photo-1552374196-c4e7ffc6e126?q=80&w=1000&auto=format&fit=crop';
const _mRock = 'https://images.unsplash.com/photo-1534030347209-71f624483863?q=80&w=1000&auto=format&fit=crop';
const _mMil = 'https://images.unsplash.com/photo-1578979879663-4ba6a968a50a?q=80&w=1000&auto=format&fit=crop';

// Women
const _wClassic = 'https://images.unsplash.com/photo-1548142342-7487a916942a?q=80&w=1000&auto=format&fit=crop';
const _wBusiness = 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=1000&auto=format&fit=crop';
const _wCasual = 'https://images.unsplash.com/photo-1485230946006-2873a384f72f?q=80&w=1000&auto=format&fit=crop';
const _wStreet = 'https://images.unsplash.com/photo-1529139574466-a302d2d3f9f4?q=80&w=1000&auto=format&fit=crop';
const _wSport = 'https://images.unsplash.com/photo-1518310383802-640c2de311b2?q=80&w=1000&auto=format&fit=crop';
const _wMin = 'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?q=80&w=1000&auto=format&fit=crop';
const _wMel = 'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?q=80&w=1000&auto=format&fit=crop';
const _wPrep = 'https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?q=80&w=1000&auto=format&fit=crop';
const _wRock = 'https://images.unsplash.com/photo-1500917293891-ef795e70e1f6?q=80&w=1000&auto=format&fit=crop';
const _wBoho = 'https://images.unsplash.com/photo-1469334031218-e382a71b716b?q=80&w=1000&auto=format&fit=crop';


// ==========================================
// MOCK DATA: Men's Styles
// ==========================================
const List<StyleInspiration> mockMaleStyles = [
  // 1. Classic / Formal
  StyleInspiration(imageUrl: _mClassic, title: 'Black Tie', category: 'Formal', tags: ['tuxedo', 'black tie']),
  StyleInspiration(imageUrl: _mClassic, title: 'Classic Suit', category: 'Formal', tags: ['charcoal suit', 'tie']),
  
  // 2. Business / Business Casual
  StyleInspiration(imageUrl: _mBusiness, title: 'Power Meeting', category: 'Business', tags: ['navy suit', 'white shirt']),
  StyleInspiration(imageUrl: _mBusiness, title: 'Office Ready', category: 'Business', tags: ['blazer', 'chinos']),
  
  // 3. Smart Casual
  StyleInspiration(imageUrl: _mPrep, title: 'Friday Office', category: 'Smart Casual', tags: ['polo', 'trousers']),
  StyleInspiration(imageUrl: _mPrep, title: 'Date Night', category: 'Smart Casual', tags: ['shirt', 'dark jeans']),

  // 4. Casual
  StyleInspiration(imageUrl: _mCasual, title: 'Weekend Coffee', category: 'Casual', tags: ['t-shirt', 'jeans']),
  StyleInspiration(imageUrl: _mCasual, title: 'Summer Walk', category: 'Casual', tags: ['linen shirt', 'shorts']),

  // 5. Streetwear
  StyleInspiration(imageUrl: _mStreet, title: 'City Hype', category: 'Streetwear', tags: ['hoodie', 'sneakers']),
  StyleInspiration(imageUrl: _mStreet, title: 'Urban Layer', category: 'Streetwear', tags: ['bomber', 'cargo']),

  // 6. Athleisure / Sport
  StyleInspiration(imageUrl: _mSport, title: 'Gym Session', category: 'Sport', tags: ['tracksuit', 'active']),
  StyleInspiration(imageUrl: _mSport, title: 'Morning Run', category: 'Sport', tags: ['shorts', 'tech fabric']),

  // 7. Minimal / Scandinavian
  StyleInspiration(imageUrl: _mMin, title: 'Scandi Clean', category: 'Minimal', tags: ['monochrome', 'clean lines']),
  StyleInspiration(imageUrl: _mMin, title: 'All Grey', category: 'Minimal', tags: ['grey', 'minimalist']),

  // 8. Workwear
  StyleInspiration(imageUrl: _mWork, title: 'Carpenter Vibe', category: 'Workwear', tags: ['denim jacket', 'boots']),
  StyleInspiration(imageUrl: _mWork, title: 'Rugged Style', category: 'Workwear', tags: ['flannel', 'raw denim']),

  // 9. Military
  StyleInspiration(imageUrl: _mMil, title: 'Tactical Look', category: 'Military', tags: ['cargo', 'olive green']),
  StyleInspiration(imageUrl: _mMil, title: 'Field Jacket', category: 'Military', tags: ['field jacket', 'boots']),

  // 10. Preppy / Old Money
  StyleInspiration(imageUrl: _mPrep, title: 'Ivy League', category: 'Preppy', tags: ['sweater', 'shirt']),
  StyleInspiration(imageUrl: _mPrep, title: 'Country Club', category: 'Preppy', tags: ['polo', 'white pants']),

  // 11. Rock / Grunge
  StyleInspiration(imageUrl: _mRock, title: 'Rockstar', category: 'Rock', tags: ['leather jacket', 'skinny jeans']),
  StyleInspiration(imageUrl: _mGue, title: '90s Grunge', category: 'Grunge', tags: ['flannel', 'ripped jeans']),
  
  // 12. Boho (Rare for men, but adding variant)
  StyleInspiration(imageUrl: _mCasual, title: 'Artsiac', category: 'Boho', tags: ['pattern shirt', 'relaxed']),
];

// ==========================================
// MOCK DATA: Women's Styles
// ==========================================
const List<StyleInspiration> mockFemaleStyles = [
  // 1. Classic / Formal
  StyleInspiration(imageUrl: _wClassic, title: 'Evening Elegance', category: 'Formal', tags: ['gown', 'black dress']),
  StyleInspiration(imageUrl: _wClassic, title: 'Cocktail Hour', category: 'Formal', tags: ['dress', 'heels']),

  // 2. Business
  StyleInspiration(imageUrl: _wBusiness, title: 'CEO Mood', category: 'Business', tags: ['pantsuit', 'blazer']),
  StyleInspiration(imageUrl: _wBusiness, title: 'Office Chic', category: 'Business', tags: ['skirt', 'blouse']),

  // 3. Smart Casual
  StyleInspiration(imageUrl: _wPrep, title: 'Brunch Ready', category: 'Smart Casual', tags: ['blazer', 'jeans']),
  StyleInspiration(imageUrl: _wPrep, title: 'Gallery Visit', category: 'Smart Casual', tags: ['trench', 'loafers']),

  // 4. Casual
  StyleInspiration(imageUrl: _wCasual, title: 'Daily Comfort', category: 'Casual', tags: ['jeans', 'sweater']),
  StyleInspiration(imageUrl: _wCasual, title: 'Summer Breeze', category: 'Casual', tags: ['sundress', 'sandals']),

  // 5. Streetwear
  StyleInspiration(imageUrl: _wStreet, title: 'Street Style', category: 'Streetwear', tags: ['oversized', 'sneakers']),
  StyleInspiration(imageUrl: _wStreet, title: 'City Layering', category: 'Streetwear', tags: ['puffer', 'track pants']),

  // 6. Athleisure / Sport
  StyleInspiration(imageUrl: _wSport, title: 'Yoga Studio', category: 'Sport', tags: ['leggings', 'top']),
  StyleInspiration(imageUrl: _wSport, title: 'Coffee Run', category: 'Sport', tags: ['hoodie', 'bike shorts']),

  // 7. Minimal
  StyleInspiration(imageUrl: _wMin, title: 'Pure White', category: 'Minimal', tags: ['white', 'clean']),
  StyleInspiration(imageUrl: _wMin, title: 'Neutral Tones', category: 'Minimal', tags: ['beige', 'silk']),

  // 8. Workwear
  StyleInspiration(imageUrl: _wMel, title: 'Utility Chic', category: 'Workwear', tags: ['cargo pants', 'boots']),

  // 9. Military
  StyleInspiration(imageUrl: _wMel, title: 'Safari Chic', category: 'Military', tags: ['khaki', 'shirt dress']),

  // 10. Preppy / Old Money
  StyleInspiration(imageUrl: _wPrep, title: 'Old Money', category: 'Preppy', tags: ['cardigan', 'pearls']),
  StyleInspiration(imageUrl: _wPrep, title: 'Tennis Club', category: 'Preppy', tags: ['pleated skirt', 'polo']),

  // 11. Rock / Grunge
  StyleInspiration(imageUrl: _wRock, title: 'Concert Ready', category: 'Rock', tags: ['leather', 'boots']),
  StyleInspiration(imageUrl: _wRock, title: '90s Vibe', category: 'Grunge', tags: ['slip dress', 't-shirt']),

  // 12. Boho
  StyleInspiration(imageUrl: _wBoho, title: 'Boho Queen', category: 'Boho', tags: ['maxi dress', 'floral']),
  StyleInspiration(imageUrl: _wBoho, title: 'Festival Look', category: 'Boho', tags: ['fringe', 'hat']),
];
