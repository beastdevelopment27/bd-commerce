import React from "react";
import { debugData } from "../utils/debugData";
import "../index.css";
import Ecommerce from "./Main/Ecommerce";
import "../styles/design-tokens.css";
import "../styles";

debugData([
  {
    action: "setVisible",
    data: true,
  },
]);

const App: React.FC = () => {
  return (
    <>
     <Ecommerce />
    </>
  );
};

export default App;
