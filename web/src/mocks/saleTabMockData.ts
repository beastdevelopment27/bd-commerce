export type MockSaleType = "Public" | "Person" | "Job";

export type MockSaleItem = {
  id: string;
  productName: string;
  description: string;
  image: string;
  inventoryItem: string;
  playerTarget: string;
  jobTarget?: string;
  quantity: string;
  price: string;
  discount: string;
  saleType: MockSaleType;
  category?: string;
};

export const saleTabMockSales: MockSaleItem[] = [
  {
    id: "sale-1001",
    productName: "Repair Kit Bundle",
    description: "Full repair bundle for emergency roadside fixes.",
    image: "",
    inventoryItem: "repair-kit",
    playerTarget: "",
    quantity: "12",
    price: "350",
    discount: "10",
    saleType: "Public",
    category: "tools",
  },
  {
    id: "sale-1002",
    productName: "Premium Water Pack",
    description: "Hydration pack with purified bottled water.",
    image: "",
    inventoryItem: "water",
    playerTarget: "",
    quantity: "4",
    price: "120",
    discount: "0",
    saleType: "Public",
    category: "food",
  },
  {
    id: "sale-1003",
    productName: "Police Supply Crate",
    description: "Restricted utility crate for active officers.",
    image: "",
    inventoryItem: "armor",
    playerTarget: "",
    jobTarget: "police",
    quantity: "8",
    price: "950",
    discount: "15",
    saleType: "Job",
    category: "materials",
  },
  {
    id: "sale-1004",
    productName: "Mechanic Starter Pack",
    description: "Basic mechanic supplies and diagnostic essentials.",
    image: "",
    inventoryItem: "toolbox",
    playerTarget: "",
    jobTarget: "mechanic",
    quantity: "2",
    price: "700",
    discount: "5",
    saleType: "Job",
    category: "tools",
  },
  {
    id: "sale-1005",
    productName: "Private Delivery",
    description: "Reserved package for a specific customer.",
    image: "",
    inventoryItem: "package",
    playerTarget: "char1:1f3b9f7c",
    quantity: "1",
    price: "2500",
    discount: "0",
    saleType: "Person",
    category: "misc",
  },
  {
    id: "sale-1006",
    productName: "Medical Supply Box",
    description: "First-aid and emergency medical essentials.",
    image: "",
    inventoryItem: "medkit",
    playerTarget: "",
    jobTarget: "ambulance",
    quantity: "0",
    price: "1250",
    discount: "20",
    saleType: "Job",
    category: "medical",
  },
];
