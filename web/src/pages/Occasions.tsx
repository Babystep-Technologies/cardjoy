import React, { useState, useMemo } from 'react';
import { occasions } from '@/config/occasions';
import { OccasionCard } from '@/components/OccasionCard';
import Reveal from '@/components/Reveal';
import { Search } from 'lucide-react';

type CategoryFilter =
  | 'all'
  | 'celebrations'
  | 'life-events'
  | 'workplace'
  | 'seasonal'
  | 'caring'
  | 'general';

const Occasions: React.FC = () => {
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<CategoryFilter>('all');

  const filteredOccasions = useMemo(() => {
    return occasions.filter(occasion => {
      const matchesSearch = occasion.name.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesCategory = categoryFilter === 'all' || occasion.category === categoryFilter;
      return matchesSearch && matchesCategory;
    });
  }, [searchQuery, categoryFilter]);

  const categories: { value: CategoryFilter; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'celebrations', label: 'Celebrations' },
    { value: 'life-events', label: 'Life Events' },
    { value: 'workplace', label: 'Workplace' },
    { value: 'seasonal', label: 'Seasonal' },
    { value: 'caring', label: 'Caring' },
    { value: 'general', label: 'Just Because' },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 via-pink-50 to-blue-50">
      {/* Hero Section */}
      <section className="pt-32 pb-16 px-4">
        <div className="max-w-7xl mx-auto text-center">
          <Reveal>
            <h1 className="text-4xl md:text-6xl font-black text-gray-900 mb-4">
              Celebrate Every Occasion with Group Cards
            </h1>
            <p className="text-lg md:text-2xl text-gray-600 mb-8 max-w-3xl mx-auto">
              Browse our collection or create something unique
            </p>

            {/* Search Bar */}
            <div className="max-w-2xl mx-auto mb-8">
              <div className="relative">
                <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search occasions..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  className="w-full pl-12 pr-4 py-4 rounded-2xl border-2 border-gray-200 focus:border-purple-400 focus:outline-none text-lg"
                />
              </div>
            </div>

            {/* Filter Pills */}
            <div className="flex flex-wrap justify-center gap-2 mb-12">
              {categories.map(category => (
                <button
                  key={category.value}
                  onClick={() => setCategoryFilter(category.value)}
                  className={`px-6 py-2 rounded-full font-semibold transition-all ${
                    categoryFilter === category.value
                      ? 'bg-purple-600 text-white shadow-lg scale-105'
                      : 'bg-white text-gray-600 hover:bg-gray-100'
                  }`}
                >
                  {category.label}
                </button>
              ))}
            </div>
          </Reveal>
        </div>
      </section>

      {/* Occasion Grid */}
      <section className="pb-24 px-4">
        <div className="max-w-7xl mx-auto">
          {filteredOccasions.length > 0 ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              {filteredOccasions.map(occasion => (
                <Reveal key={occasion.slug}>
                  <OccasionCard occasion={occasion} />
                </Reveal>
              ))}
            </div>
          ) : (
            <div className="text-center py-16">
              <p className="text-2xl text-gray-600">No occasions found matching "{searchQuery}"</p>
              <button
                onClick={() => {
                  setSearchQuery('');
                  setCategoryFilter('all');
                }}
                className="mt-4 px-6 py-3 bg-purple-600 text-white rounded-full font-semibold hover:bg-purple-700 transition-colors"
              >
                Clear Filters
              </button>
            </div>
          )}
        </div>
      </section>
    </div>
  );
};

export default Occasions;
