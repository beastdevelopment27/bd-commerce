import * as React from "react";
import { fetchNui } from "@/utils/fetchNui";

export type NotificationType = "success" | "error" | "info" | "warning";

export type Notification = {
  id: string;
  type: NotificationType;
  title: string;
  message?: string;
  duration?: number;
};

type NotificationContextValue = {
  notify: (type: NotificationType, title: string, message?: string) => void;
  success: (title: string, message?: string) => void;
  error: (title: string, message?: string) => void;
  info: (title: string, message?: string) => void;
  warning: (title: string, message?: string) => void;
};

const NotificationContext = React.createContext<NotificationContextValue | null>(null);

const DEFAULT_DURATION = 4000;

export function NotificationProvider({ children }: { children: React.ReactNode }) {
  const addNotification = React.useCallback(
    (type: NotificationType, title: string, message?: string, duration = DEFAULT_DURATION) => {
      // Routes to game notification (config/notifications.lua → client/notifications.lua).
      const text = message && message.length > 0 ? `${title}: ${message}` : title;
      fetchNui("notifyServer", { message: text, type, duration }).catch(() => {});
    },
    []
  );

  const value = React.useMemo(
    () => ({
      notify: addNotification,
      success: (title: string, message?: string) => addNotification("success", title, message),
      error: (title: string, message?: string) => addNotification("error", title, message),
      info: (title: string, message?: string) => addNotification("info", title, message),
      warning: (title: string, message?: string) => addNotification("warning", title, message),
    }),
    [addNotification]
  );

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  );
}

export function useNotification() {
  const ctx = React.useContext(NotificationContext);
  if (!ctx) throw new Error("useNotification must be used within NotificationProvider");
  return ctx;
}
