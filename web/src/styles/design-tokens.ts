export const designTokens = {
  /* Background Layers (Deeper + Richer Blacks) */
  bg: {
    main: "#0F1115",
    secondary: "#14161B",
    card: "#181B21",
    elevated: "#1D2128",
    sidebar: "#121419",
  },

  /* Borders (Use opacity for premium feel) */
  border: {
    subtle: "rgba(255,255,255,0.05)",
    default: "rgba(255,255,255,0.08)",
    strong: "rgba(255,255,255,0.12)",
  },

  /* Interactive Surfaces */
  surface: {
    hover: "#1F232B",
    pressed: "#16191F",
  },

  /* 💰 Premium Gold (Richer + Warmer) */
  gold: {
    primary: "#E0C27A",
    hover: "#E8CC8A",
    active: "#BFA15A",

    glow: {
      soft: "rgba(224,194,122,0.10)",
      medium: "rgba(224,194,122,0.18)",
      strong: "rgba(224,194,122,0.26)",
    },

    /* Gradient = key for premium */
    gradient: "linear-gradient(135deg, #E0C27A 0%, #C6A962 40%, #9F8445 100%)",
  },

  /* Text (Cleaner hierarchy) */
  text: {
    primary: "#F5F7FA",
    secondary: "#B0B6BF",
    muted: "#7C828C",
    disabled: "#565B65",
    accent: "#E0C27A",
  },

  /* Buttons (Luxury depth) */
  button: {
    primary: {
      bg: "linear-gradient(135deg, #E0C27A, #C6A962)",
      hover: "linear-gradient(135deg, #E8CC8A, #D4B46A)",
      active: "#BFA15A",
      text: "#0F1115",

      /* layered shadow = premium */
      shadow: `
        0 8px 24px rgba(224,194,122,0.18),
        0 2px 6px rgba(0,0,0,0.4)
      `,
    },

    secondary: {
      bg: "#181B21",
      hover: "#1F232B",
      active: "#15181D",
      border: "rgba(255,255,255,0.08)",
      text: "#F5F7FA",
    },

    ghost: {
      text: "#B0B6BF",
      hoverText: "#FFFFFF",
      hoverBg: "rgba(255,255,255,0.05)",
    },
  },

  /* Inputs (Glass + focus glow) */
  input: {
    bg: "#181B21",
    border: "rgba(255,255,255,0.08)",
    hoverBorder: "rgba(255,255,255,0.14)",
    focusBorder: "#E0C27A",
    focusGlow: "rgba(224,194,122,0.18)",
    text: "#F5F7FA",
    placeholder: "#7C828C",
    disabledBg: "#121419",
  },

  /* Sidebar */
  sidebar: {
    bg: "#121419",
    text: "#B0B6BF",
    icon: "#7C828C",

    hoverBg: "#1F232B",
    hoverText: "#FFFFFF",

    activeBg: "rgba(224,194,122,0.08)",
    activeAccent: "#E0C27A",
    activeText: "#FFFFFF",
    activeIcon: "#E0C27A",
  },

  /* Cards (Premium depth layering) */
  card: {
    bg: "#181B21",
    hover: "#1F232B",
    border: "rgba(255,255,255,0.06)",

    shadow: `
      0 20px 50px rgba(0,0,0,0.6),
      0 1px 0 rgba(255,255,255,0.04) inset
    `,

    statNumber: "#E0C27A",
    statLabel: "#7C828C",
  },

  /* Status (Slightly toned for elegance) */
  status: {
    success: "#5FCB6F",
    successSoft: "rgba(95,203,111,0.12)",

    warning: "#E8B04C",
    warningSoft: "rgba(232,176,76,0.12)",

    error: "#E06A6A",
    errorSoft: "rgba(224,106,106,0.12)",

    info: "#5AA0FF",
    infoSoft: "rgba(90,160,255,0.12)",
  },

  /* Radius (Softer curves = modern premium) */
  radius: {
    sm: "8px",
    md: "12px",
    lg: "18px",
    xl: "22px",
  },
} as const;