
## Enhanced Dashboard with Charts and Analytics

### Overview

Add a comprehensive analytics section to the Admin Dashboard with multiple chart types showing growth trends, comparisons, and key performance indicators. The charts will use the existing `recharts` library and follow the current design patterns.

---

### Data Sources Available

Based on the database schema, we can visualize:

| Data Category | Tables | Metrics |
|--------------|--------|---------|
| **Production** | `milk_production` | Daily/weekly/monthly trends, morning vs evening, per-cattle performance |
| **Revenue** | `invoices`, `payments` | Monthly revenue growth, collection rates, pending amounts |
| **Expenses** | `expenses` | Category-wise breakdown, monthly trends |
| **Customers** | `customers`, `deliveries` | Growth rate, active vs inactive, delivery completion |
| **Cattle** | `cattle`, `breeding_records` | Herd composition, lactation status, breeding cycles |
| **Procurement** | `milk_procurement` | Vendor-wise, quality metrics (FAT/SNF) |

---

### New Dashboard Components

#### 1. Revenue Growth Chart (Area Chart)
**File:** `src/components/dashboard/RevenueGrowthChart.tsx`

- **Chart Type:** Area chart with gradient fill
- **Data:** Last 6 months revenue comparison
- **Metrics:** Total billed, collected, pending
- **Color scheme:** Green gradient for revenue growth

```text
+------------------------------------------+
|  Revenue Growth (Last 6 Months)          |
|  ┌────────────────────────────────────┐  |
|  │        ╱╲                          │  |
|  │   ╱╲  ╱  ╲    ╱╲                   │  |
|  │  ╱  ╲╱    ╲  ╱  ╲ ╱╲               │  |
|  │ ╱          ╲╱    ╲╱  ╲              │  |
|  └────────────────────────────────────┘  |
|  Jan  Feb  Mar  Apr  May  Jun            |
+------------------------------------------+
```

---

#### 2. Expense Category Pie Chart
**File:** `src/components/dashboard/ExpensePieChart.tsx`

- **Chart Type:** Donut/Pie chart
- **Data:** Current month expenses by category
- **Categories:** Feed, Veterinary, Equipment, Salary, Utilities, Others
- **Interactive:** Hover to show amounts

---

#### 3. Cattle Herd Composition Chart
**File:** `src/components/dashboard/CattleCompositionChart.tsx`

- **Chart Type:** Horizontal bar chart or stacked bar
- **Data:** Cattle distribution by status
- **Segments:** Lactating, Dry, Pregnant, Heifer, Bull
- **Color coding:** Different colors for each status

---

#### 4. Delivery Performance Chart
**File:** `src/components/dashboard/DeliveryPerformanceChart.tsx`

- **Chart Type:** Radial bar chart / Progress ring
- **Data:** Today's and weekly delivery completion rate
- **Metrics:** Delivered vs Pending vs Cancelled
- **Visual:** Circular progress indicator

---

#### 5. Month-over-Month Comparison Card
**File:** `src/components/dashboard/MonthComparisonChart.tsx`

- **Chart Type:** Grouped bar chart
- **Data:** This month vs last month
- **Metrics:** Production, Revenue, Customers, Deliveries
- **Shows:** Growth/decline percentages

---

#### 6. Customer Growth Trend
**File:** `src/components/dashboard/CustomerGrowthChart.tsx`

- **Chart Type:** Line chart with points
- **Data:** Customer acquisition over last 12 months
- **Additional:** Active vs Total customers comparison

---

#### 7. Procurement vs Production Comparison
**File:** `src/components/dashboard/ProcurementProductionChart.tsx`

- **Chart Type:** Dual-axis combo chart (Bar + Line)
- **Data:** Daily milk procured vs produced (last 7 days)
- **Purpose:** Compare external procurement with farm production

---

### Updated Dashboard Hook

**File:** `src/hooks/useDashboardCharts.ts`

New hook to fetch all chart data efficiently:

```typescript
interface DashboardChartData {
  revenueGrowth: MonthlyRevenue[];
  expenseBreakdown: ExpenseCategory[];
  cattleComposition: CattleStatus[];
  deliveryPerformance: DeliveryStats;
  monthComparison: MonthComparison;
  customerGrowth: CustomerTrend[];
  procurementVsProduction: DailyComparison[];
}
```

- Parallel data fetching for performance
- 5-minute cache time
- Graceful error handling

---

### Updated Admin Dashboard Layout

**File:** `src/components/dashboard/AdminDashboard.tsx`

New layout structure:

```text
+--------------------------------------------------+
|  Quick Actions Card                              |
+--------------------------------------------------+
|  Stat Cards (4 columns)                          |
+--------------------------------------------------+
|  Weekly Production  |  Recent Activity           |
|  (existing)         |  (existing)                |
+--------------------------------------------------+
|  Revenue Growth Chart (full width)               |
+--------------------------------------------------+
|  Expense Pie  |  Cattle Composition  |  Delivery |
|  Chart        |  Chart               |  Progress |
+--------------------------------------------------+
|  Month Comparison  |  Customer Growth            |
+--------------------------------------------------+
|  Production Insights (existing)                  |
+--------------------------------------------------+
|  Breeding Alerts | Delivery Auto | Expense Auto  |
+--------------------------------------------------+
```

---

### Implementation Details

#### Chart Styling Guidelines

All charts will follow the existing design system:
- Use CSS variables: `hsl(var(--chart-1))` through `hsl(var(--chart-5))`
- Consistent tooltip styling matching `ProductionChart.tsx`
- Responsive containers using `ResponsiveContainer`
- Loading skeletons matching existing patterns
- Framer Motion animations for entry effects

#### Color Palette for Charts

```typescript
const CHART_COLORS = {
  primary: 'hsl(152, 45%, 28%)',    // Green (production)
  secondary: 'hsl(158, 50%, 45%)',  // Light green
  success: 'hsl(142, 76%, 36%)',    // Success green
  warning: 'hsl(38, 92%, 50%)',     // Amber
  info: 'hsl(199, 89%, 48%)',       // Blue
  destructive: 'hsl(0, 72%, 51%)',  // Red
};
```

---

### Files to Create

| File | Purpose |
|------|---------|
| `src/hooks/useDashboardCharts.ts` | Data fetching hook for all charts |
| `src/components/dashboard/RevenueGrowthChart.tsx` | 6-month revenue area chart |
| `src/components/dashboard/ExpensePieChart.tsx` | Expense category donut chart |
| `src/components/dashboard/CattleCompositionChart.tsx` | Herd status bar chart |
| `src/components/dashboard/DeliveryPerformanceChart.tsx` | Delivery completion radial chart |
| `src/components/dashboard/MonthComparisonChart.tsx` | This vs last month comparison |
| `src/components/dashboard/CustomerGrowthChart.tsx` | Customer acquisition trend |

### Files to Modify

| File | Changes |
|------|---------|
| `src/components/dashboard/AdminDashboard.tsx` | Add new chart components to layout |

---

### Technical Considerations

1. **Performance**: All queries run in parallel using `Promise.all`
2. **Caching**: 5-minute stale time to reduce database load
3. **Responsive**: Charts adapt to mobile/tablet/desktop
4. **Empty States**: Graceful handling when no data exists
5. **Skeleton Loading**: Consistent loading states for each chart
6. **Animations**: Smooth entry animations using Framer Motion

---

### Chart Component Structure

Each chart component will follow this pattern:

```typescript
export function ChartComponent() {
  const { data, isLoading } = useQuery({
    queryKey: ["chart-name"],
    queryFn: fetchChartData,
    staleTime: 5 * 60 * 1000,
  });

  if (isLoading) return <ChartSkeleton />;
  if (!data?.length) return <EmptyChartState />;

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
      <Card>
        <CardHeader>
          <CardTitle>Chart Title</CardTitle>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer>
            {/* Chart implementation */}
          </ResponsiveContainer>
        </CardContent>
      </Card>
    </motion.div>
  );
}
```

---

### Result After Implementation

- 6 new chart components providing comprehensive business insights
- Visual comparisons for growth tracking
- Category-wise expense analysis
- Herd health and composition overview
- Delivery performance tracking
- Customer acquisition trends
- Procurement vs production analysis
- All charts mobile-responsive with smooth animations
