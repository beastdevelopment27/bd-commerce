import React from 'react';
import ReactDOM from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import { VisibilityProvider } from './providers/VisibilityProvider';
import { NotificationProvider } from './components/ui/notification';
import App from './components/App';
// Design system: load tokens first so CSS variables (--ds-*) and TS designTokens are available app-wide
import './styles/design-tokens.css';
import './styles'; // loads design-tokens.ts so components can import { designTokens } from '@/styles'
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <HashRouter
      future={{
        v7_startTransition: true,
        v7_relativeSplatPath: true,
      }}
    >
      <VisibilityProvider>
        <NotificationProvider>
          <App />
        </NotificationProvider>
      </VisibilityProvider>
    </HashRouter>
  </React.StrictMode>,
);
