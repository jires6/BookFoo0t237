// Firebase configuration for web
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyDSwqP7IDiNudhzAIfZMPiMFhFFedMZMow",
  authDomain: "bookfoot237-99459.firebaseapp.com",
  projectId: "bookfoot237-99459",
  storageBucket: "bookfoot237-99459.firebasestorage.app",
  messagingSenderId: "625512642632",
  appId: "1:625512642632:web:206518a861e1e3175e007d",
  measurementId: "G-MR8X8VNH79"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase Authentication and get a reference to the service
export const auth = getAuth(app);

// Initialize Cloud Firestore and get a reference to the service
export const db = getFirestore(app);

export default app;