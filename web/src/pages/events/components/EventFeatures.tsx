import { FeatureConfig } from '../configs/types';
import Reveal from '../../../components/Reveal';
import { Card, CardContent } from '../../../components/ui/card';

interface EventFeaturesProps {
  features: FeatureConfig[];
}

export const EventFeatures: React.FC<EventFeaturesProps> = ({ features }) => {
  return (
    <section className="py-20 px-4 sm:px-6 lg:px-10 bg-white">
      <div className="max-w-6xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {features.map((feature, index) => {
            const Icon = feature.icon;
            return (
              <Reveal key={index} delay={index * 0.2}>
                <Card className="h-full hover:shadow-lg transition-shadow border-2">
                  <CardContent className="p-8 text-center">
                    <div className="flex justify-center mb-4">
                      <div className="bg-gradient-to-br from-pink-100 to-purple-100 p-4 rounded-full">
                        <Icon className="w-8 h-8 text-pink-600" />
                      </div>
                    </div>
                    <h3 className="text-2xl font-bold text-gray-900 mb-3">{feature.title}</h3>
                    <p className="text-base md:text-lg text-gray-700">{feature.description}</p>
                  </CardContent>
                </Card>
              </Reveal>
            );
          })}
        </div>
      </div>
    </section>
  );
};
