import React from 'react';
import Header from '@/components/Header';
import Footer from '@/components/Footer';

type Props = {
  children: React.ReactNode;
};

const RootLayout: React.FC<Props> = ({ children }) => {
  const isStaging = import.meta.env.VITE_ENV === 'staging';

  return (
    <div
      className="antialiased flex flex-col min-h-screen"
      style={{
        fontFamily: "'Montserrat', sans-serif",
      }}
    >
      <Header />
      <main className={`flex-grow ${isStaging ? 'pt-[104px]' : 'pt-12'}`}>{children}</main>
      <Footer />
    </div>
  );
};

export default RootLayout;
