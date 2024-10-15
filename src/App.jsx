import { RouterProvider } from "react-router-dom";
import { ThemeProvider } from "./contexts/ThemeContext";
import { router } from "./Router";
import { AuthProvider } from "./lib/useAuthClient";

//import './App.css'

function App() {
  console.log(`[App] env:`, process.env);
  
  return (
    <ThemeProvider>
      <AuthProvider>
        <RouterProvider router={router} />
      </AuthProvider>
    </ThemeProvider>
  )

}

export default App
