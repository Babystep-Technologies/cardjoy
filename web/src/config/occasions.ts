export interface OccasionMenuItem {
  name: string;
  slug: string; // URL slug (e.g., "baby-shower")
  description: string;
  imageUrl: string; // For mega menu and directory
  color: string; // Gradient classes
  category: 'celebrations' | 'life-events' | 'workplace' | 'seasonal' | 'caring' | 'general';
  featured: boolean; // Show in mega menu
  hasLandingPage: boolean; // Has dedicated /for/{slug} page
}

export const occasions: OccasionMenuItem[] = [
  {
    name: 'Birthday',
    slug: 'birthday',
    description: 'Make their special day unforgettable with messages from everyone',
    imageUrl:
      'https://images.unsplash.com/photo-1558636508-e0db3814bd1d?w=400&auto=format&fit=crop',
    color: 'from-pink-400 via-purple-400 to-pink-500',
    category: 'celebrations',
    featured: true,
    hasLandingPage: true,
  },
  {
    name: 'Wedding',
    slug: 'wedding',
    description: 'Celebrate their forever with heartfelt congratulations',
    imageUrl:
      'https://images.unsplash.com/photo-1519741497674-611481863552?w=400&auto=format&fit=crop',
    color: 'from-rose-300 via-pink-200 to-white',
    category: 'celebrations',
    featured: true,
    hasLandingPage: true,
  },
  {
    name: 'Baby Shower',
    slug: 'baby-shower',
    description: 'Welcome the new arrival with love and well wishes',
    imageUrl:
      'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?w=400&auto=format&fit=crop',
    color: 'from-blue-200 via-cyan-100 to-pink-100',
    category: 'celebrations',
    featured: true,
    hasLandingPage: true,
  },
  {
    name: 'Graduation',
    slug: 'graduation',
    description: 'Congratulate their achievement and bright future',
    imageUrl:
      'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=400&auto=format&fit=crop',
    color: 'from-yellow-400 via-orange-300 to-yellow-500',
    category: 'celebrations',
    featured: true,
    hasLandingPage: true,
  },
  {
    name: 'New Job',
    slug: 'new-job',
    description: 'Celebrate their career success and new beginning',
    imageUrl:
      'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=400&auto=format&fit=crop',
    color: 'from-green-400 via-emerald-400 to-teal-400',
    category: 'workplace',
    featured: true,
    hasLandingPage: true,
  },
  {
    name: "Valentine's Day",
    slug: 'valentines-day',
    description: 'Share love and affection with everyone who cares',
    imageUrl:
      'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=400&auto=format&fit=crop',
    color: 'from-pink-100 via-purple-100 to-red-100',
    category: 'seasonal',
    featured: true,
    hasLandingPage: true,
  },
  {
    name: 'Anniversary',
    slug: 'anniversary',
    description: 'Celebrate years of love and commitment',
    imageUrl:
      'https://images.unsplash.com/photo-1464047736614-af63643285bf?w=400&auto=format&fit=crop',
    color: 'from-red-400 to-pink-500',
    category: 'celebrations',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Retirement',
    slug: 'retirement',
    description: 'Honor their career and wish them well',
    imageUrl:
      'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=400&auto=format&fit=crop',
    color: 'from-cyan-400 to-blue-500',
    category: 'workplace',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Farewell',
    slug: 'farewell',
    description: 'Send them off with warm memories and good wishes',
    imageUrl:
      'https://images.unsplash.com/photo-1528605248644-14dd04022da1?w=400&auto=format&fit=crop',
    color: 'from-purple-400 to-indigo-500',
    category: 'workplace',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Job Farewell',
    slug: 'job-farewell',
    description: "Show them they're not forgotten with a free group goodbye card",
    imageUrl:
      'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=400&auto=format&fit=crop',
    color: 'from-amber-400 via-orange-400 to-yellow-400',
    category: 'workplace',
    featured: false,
    hasLandingPage: true,
  },
  {
    name: 'Welcome',
    slug: 'welcome',
    description: 'Make them feel at home with a warm greeting',
    imageUrl:
      'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=400&auto=format&fit=crop',
    color: 'from-green-400 to-emerald-500',
    category: 'workplace',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Thank You',
    slug: 'thank-you',
    description: 'Express gratitude and appreciation',
    imageUrl:
      'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?w=400&auto=format&fit=crop',
    color: 'from-amber-400 to-yellow-500',
    category: 'caring',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Get Well Soon',
    slug: 'get-well-soon',
    description: 'Send healing thoughts and encouragement',
    imageUrl:
      'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=400&auto=format&fit=crop',
    color: 'from-green-300 to-teal-400',
    category: 'caring',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Sympathy',
    slug: 'sympathy',
    description: 'Share condolences and support during difficult times',
    imageUrl:
      'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=400&auto=format&fit=crop',
    color: 'from-gray-300 to-slate-400',
    category: 'caring',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Congratulations',
    slug: 'congratulations',
    description: 'Celebrate any achievement or milestone',
    imageUrl:
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=400&auto=format&fit=crop',
    color: 'from-yellow-300 to-orange-400',
    category: 'general',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Just Because',
    slug: 'just-because',
    description: 'Show someone you care, no reason needed',
    imageUrl:
      'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?w=400&auto=format&fit=crop',
    color: 'from-purple-300 to-pink-300',
    category: 'general',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Holiday',
    slug: 'holiday',
    description: 'Spread joy during the festive season',
    imageUrl:
      'https://images.unsplash.com/photo-1512389142860-9c449e58a543?w=400&auto=format&fit=crop',
    color: 'from-red-400 to-green-400',
    category: 'seasonal',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'New Home',
    slug: 'new-home',
    description: 'Celebrate their new place to call home',
    imageUrl:
      'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=400&auto=format&fit=crop',
    color: 'from-blue-300 to-indigo-400',
    category: 'life-events',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Promotion',
    slug: 'promotion',
    description: 'Recognize their career advancement',
    imageUrl:
      'https://images.unsplash.com/photo-1552664730-d307ca884978?w=400&auto=format&fit=crop',
    color: 'from-emerald-400 to-green-500',
    category: 'workplace',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Engagement',
    slug: 'engagement',
    description: 'Celebrate the promise of forever',
    imageUrl:
      'https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?w=400&auto=format&fit=crop',
    color: 'from-pink-300 to-rose-400',
    category: 'life-events',
    featured: false,
    hasLandingPage: false,
  },
  {
    name: 'Good Luck',
    slug: 'good-luck',
    description: 'Send encouragement for their next adventure',
    imageUrl:
      'https://images.unsplash.com/photo-1494587351196-bbf5f29cff42?w=400&auto=format&fit=crop',
    color: 'from-green-300 to-cyan-400',
    category: 'general',
    featured: false,
    hasLandingPage: false,
  },
];
