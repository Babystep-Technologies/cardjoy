import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts';

interface DataPoint {
  date: string;
  [key: string]: string | number;
}

interface TrendChartProps {
  title: string;
  data: DataPoint[];
  lines: Array<{
    dataKey: string;
    name: string;
    color: string;
  }>;
}

export default function TrendChart({ title, data, lines }: TrendChartProps) {
  // Format date for display (show only month/day)
  const formatXAxis = (dateStr: string) => {
    const date = new Date(dateStr);
    return `${date.getMonth() + 1}/${date.getDate()}`;
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg font-bold">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={data} margin={{ top: 5, right: 10, left: 0, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis
              dataKey="date"
              tickFormatter={formatXAxis}
              tick={{ fontSize: 12 }}
              stroke="#666"
            />
            <YAxis tick={{ fontSize: 12 }} stroke="#666" />
            <Tooltip
              contentStyle={{
                backgroundColor: 'white',
                border: '1px solid #ccc',
                borderRadius: '4px',
              }}
              labelFormatter={label => {
                const date = new Date(label);
                return date.toLocaleDateString();
              }}
            />
            <Legend wrapperStyle={{ fontSize: '12px' }} />
            {lines.map(line => (
              <Line
                key={line.dataKey}
                type="monotone"
                dataKey={line.dataKey}
                name={line.name}
                stroke={line.color}
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4 }}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
