export type BuyListingMockSaleItem = {
  id: string;
  productName: string;
  description: string;
  inventoryItem: string;
  quantity: string;
  price: string;
  discount: string;
  saleType: string;
  jobTarget?: string;
  image: string;
  category?: string;
  sellerRatingAvg?: number | null;
  sellerRatingCount?: number;
};

export const buyListingMockSales: BuyListingMockSaleItem[] = [
  {
    id: "public-2001",
    productName: "Pistol Ammo",
    description: "Standard handgun ammo pack.sdhbgksdhgsdhglsdhglsdhglsdhglhsdglkhsdglkhsdghsdfklgsdfzjklghsdkfjlhgsdlfkjghSDKJLFHgbKLSJDFFHgJKSLDFhgKSJDFGHKLJSDFFHGjklzdfhbjkldfzhgkjzdfbhgzkljdfhgzdfjklgzdfkjghzdfjkghzdfkj;ghzdfkjghzdfkj;ghbzdf;kjgzdxfk;jghzdfk;jghzdf;ikjghbkjzdfbgh",
    inventoryItem: "pistol_ammo",
    quantity: "12",
    price: "1200",
    discount: "5",
    saleType: "Public",
    image: "pistol_ammo",
    category: "ammo",
    sellerRatingAvg: 4.5,
    sellerRatingCount: 12,
  },
  {
    id: "public-2002",
    productName: "Burger Meal",
    description: "Quick meal combo with drink.",
    inventoryItem: "burger",
    quantity: "8",
    price: "95",
    discount: "5",
    saleType: "Public",
    image: "burger",
    category: "food",
    sellerRatingAvg: 4.2,
    sellerRatingCount: 3,
  },
  {
    id: "public-2003",
    productName: "Cash Bundle",
    description: "Stacked cash bundle display item.",
    inventoryItem: "cash_bundle",
    quantity: "10",
    price: "5000",
    discount: "0",
    saleType: "Person",
    image: "cash",
    category: "misc",
  },
  {
    id: "public-2004",
    productName: "Rifle Ammo",
    description: "High-caliber ammo for rifles.",
    inventoryItem: "rifle_ammo",
    quantity: "2",
    price: "2200",
    discount: "10",
    saleType: "Job",
    jobTarget: "police",
    image: "rifle_ammo",
    category: "ammo",
  },
  {
    id: "public-2005",
    productName: "First Aid Kit",
    description: "Emergency medical kit for field use.",
    inventoryItem: "medkit",
    quantity: "0",
    price: "750",
    discount: "0",
    saleType: "Public",
    image: "medkit",
    category: "medical",
  },
];
