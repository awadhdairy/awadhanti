import { useState, useMemo } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { cn } from "@/lib/utils";
import {
  format,
  startOfMonth,
  endOfMonth,
  eachDayOfInterval,
  isSameMonth,
  isSameDay,
  addMonths,
  subMonths,
  getDay,
  startOfWeek,
  endOfWeek,
  isToday,
  parseISO,
} from "date-fns";
import {
  ChevronLeft,
  ChevronRight,
  CheckCircle,
  XCircle,
  Clock,
  Package,
  Sparkles,
  Palmtree,
} from "lucide-react";

interface DeliveryItem {
  id: string;
  product_name: string;
  quantity: number;
  unit_price: number;
  total_amount: number;
}

interface Delivery {
  id: string;
  delivery_date: string;
  delivery_time: string | null;
  status: string;
  notes: string | null;
  items: DeliveryItem[];
}

interface Subscription {
  id: string;
  product_id: string;
  product_name: string;
  quantity: number;
  custom_price: number | null;
  base_price: number;
  is_active: boolean;
}

interface Vacation {
  id: string;
  start_date: string;
  end_date: string;
  reason: string | null;
  is_active: boolean;
}

interface CustomerDeliveryCalendarProps {
  deliveries: Delivery[];
  subscriptions: Subscription[];
  vacations: Vacation[];
  subscriptionType: string;
}

export function CustomerDeliveryCalendar({
  deliveries,
  subscriptions,
  vacations,
  subscriptionType,
}: CustomerDeliveryCalendarProps) {
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);

  // Create a map of deliveries by date for quick lookup
  const deliveryMap = useMemo(() => {
    const map = new Map<string, Delivery>();
    deliveries.forEach((d) => {
      map.set(d.delivery_date, d);
    });
    return map;
  }, [deliveries]);

  // Create a set of vacation dates
  const vacationDates = useMemo(() => {
    const dates = new Set<string>();
    vacations
      .filter((v) => v.is_active)
      .forEach((v) => {
        const start = parseISO(v.start_date);
        const end = parseISO(v.end_date);
        const days = eachDayOfInterval({ start, end });
        days.forEach((d) => dates.add(format(d, "yyyy-MM-dd")));
      });
    return dates;
  }, [vacations]);

  // Get active subscriptions for display
  const activeSubscriptions = useMemo(
    () => subscriptions.filter((s) => s.is_active),
    [subscriptions]
  );

  // Calculate expected delivery value per day
  const dailySubscriptionValue = useMemo(() => {
    return activeSubscriptions.reduce(
      (sum, s) => sum + (s.custom_price ?? s.base_price) * s.quantity,
      0
    );
  }, [activeSubscriptions]);

  // Get calendar days including padding for the week
  const calendarDays = useMemo(() => {
    const monthStart = startOfMonth(currentMonth);
    const monthEnd = endOfMonth(currentMonth);
    const calendarStart = startOfWeek(monthStart);
    const calendarEnd = endOfWeek(monthEnd);
    return eachDayOfInterval({ start: calendarStart, end: calendarEnd });
  }, [currentMonth]);

  // Check if a date is an expected delivery date based on subscription type
  const isExpectedDeliveryDate = (date: Date): boolean => {
    const dayOfWeek = getDay(date);
    switch (subscriptionType) {
      case "daily":
        return true;
      case "alternate": {
        const refDate = new Date(2024, 0, 1);
        const daysSinceRef = Math.floor(
          (date.getTime() - refDate.getTime()) / (1000 * 60 * 60 * 24)
        );
        return daysSinceRef % 2 === 0;
      }
      case "weekly":
        return dayOfWeek === 0; // Sunday
      default:
        return true;
    }
  };

  // Get delivery data for a specific date
  const getDeliveryForDate = (date: Date) => {
    const dateStr = format(date, "yyyy-MM-dd");
    return deliveryMap.get(dateStr);
  };

  // Check if date is on vacation
  const isOnVacation = (date: Date) => {
    return vacationDates.has(format(date, "yyyy-MM-dd"));
  };

  // Check if delivery has add-on items (items not in subscription)
  const getAddOnItems = (delivery: Delivery) => {
    const subscriptionProductIds = new Set(activeSubscriptions.map((s) => s.product_id));
    return delivery.items.filter(
      (item) => !subscriptionProductIds.has(item.product_name) // Fallback check by name
    );
  };

  // Check if delivery has modified quantities compared to subscription
  const hasModifiedQuantities = (delivery: Delivery) => {
    for (const item of delivery.items) {
      const sub = activeSubscriptions.find(
        (s) => s.product_name === item.product_name
      );
      if (sub && sub.quantity !== item.quantity) {
        return true;
      }
    }
    return false;
  };

  // Selected date details
  const selectedDelivery = selectedDate ? getDeliveryForDate(selectedDate) : null;
  const isSelectedOnVacation = selectedDate ? isOnVacation(selectedDate) : false;
  const isSelectedExpected = selectedDate ? isExpectedDeliveryDate(selectedDate) : false;

  // Month stats
  const monthStats = useMemo(() => {
    const monthStart = startOfMonth(currentMonth);
    const monthEnd = endOfMonth(currentMonth);
    const days = eachDayOfInterval({ start: monthStart, end: monthEnd });

    let delivered = 0;
    let missed = 0;
    let pending = 0;
    let totalValue = 0;
    let addOnValue = 0;

    days.forEach((day) => {
      const delivery = getDeliveryForDate(day);
      if (delivery) {
        if (delivery.status === "delivered") delivered++;
        else if (delivery.status === "missed") missed++;
        else if (delivery.status === "pending") pending++;

        // Calculate total value
        delivery.items.forEach((item) => {
          totalValue += item.total_amount;
        });
      }
    });

    return { delivered, missed, pending, totalValue, addOnValue };
  }, [currentMonth, deliveries]);

  return (
    <Card>
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-sm flex items-center gap-2">
            Delivery Calendar
          </CardTitle>
          <div className="flex items-center gap-1">
            <Button
              variant="ghost"
              size="icon"
              className="h-8 w-8"
              onClick={() => setCurrentMonth(subMonths(currentMonth, 1))}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <span className="text-sm font-medium min-w-[120px] text-center">
              {format(currentMonth, "MMMM yyyy")}
            </span>
            <Button
              variant="ghost"
              size="icon"
              className="h-8 w-8"
              onClick={() => setCurrentMonth(addMonths(currentMonth, 1))}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        </div>
        {/* Month Stats */}
        <div className="flex gap-2 mt-2 flex-wrap">
          <Badge variant="default" className="text-xs">
            <CheckCircle className="h-3 w-3 mr-1" />
            {monthStats.delivered} delivered
          </Badge>
          <Badge variant="destructive" className="text-xs">
            <XCircle className="h-3 w-3 mr-1" />
            {monthStats.missed} missed
          </Badge>
          <Badge variant="secondary" className="text-xs">
            <Clock className="h-3 w-3 mr-1" />
            {monthStats.pending} pending
          </Badge>
          <Badge variant="outline" className="text-xs ml-auto">
            ₹{monthStats.totalValue.toLocaleString()}
          </Badge>
        </div>
      </CardHeader>
      <CardContent>
        {/* Calendar Grid */}
        <div className="grid grid-cols-7 gap-1 mb-2">
          {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map((day) => (
            <div
              key={day}
              className="text-center text-xs font-medium text-muted-foreground py-1"
            >
              {day}
            </div>
          ))}
        </div>
        <div className="grid grid-cols-7 gap-1">
          {calendarDays.map((day) => {
            const delivery = getDeliveryForDate(day);
            const isVacation = isOnVacation(day);
            const isExpected = isExpectedDeliveryDate(day);
            const isCurrentMonth = isSameMonth(day, currentMonth);
            const isSelected = selectedDate && isSameDay(day, selectedDate);
            const hasAddOns = delivery && delivery.items.length > activeSubscriptions.length;

            let bgColor = "";
            let textColor = "";
            let icon = null;

            if (isVacation) {
              bgColor = "bg-amber-100 dark:bg-amber-900/30";
              textColor = "text-amber-700 dark:text-amber-300";
              icon = <Palmtree className="h-3 w-3" />;
            } else if (delivery) {
              if (delivery.status === "delivered") {
                bgColor = "bg-green-100 dark:bg-green-900/30";
                textColor = "text-green-700 dark:text-green-300";
                icon = <CheckCircle className="h-3 w-3" />;
              } else if (delivery.status === "missed") {
                bgColor = "bg-red-100 dark:bg-red-900/30";
                textColor = "text-red-700 dark:text-red-300";
                icon = <XCircle className="h-3 w-3" />;
              } else if (delivery.status === "pending") {
                bgColor = "bg-blue-100 dark:bg-blue-900/30";
                textColor = "text-blue-700 dark:text-blue-300";
                icon = <Clock className="h-3 w-3" />;
              }
            } else if (isExpected && isCurrentMonth) {
              bgColor = "bg-muted/50";
            }

            return (
              <Popover key={day.toISOString()}>
                <PopoverTrigger asChild>
                  <button
                    onClick={() => setSelectedDate(day)}
                    className={cn(
                      "relative h-10 w-full rounded-md text-sm transition-all hover:ring-2 hover:ring-primary/50",
                      bgColor,
                      textColor,
                      !isCurrentMonth && "opacity-30",
                      isToday(day) && "ring-2 ring-primary",
                      isSelected && "ring-2 ring-primary bg-primary/10"
                    )}
                  >
                    <span className="absolute top-1 left-1.5 text-xs">
                      {format(day, "d")}
                    </span>
                    {icon && (
                      <span className="absolute bottom-1 right-1">{icon}</span>
                    )}
                    {hasAddOns && (
                      <span className="absolute top-1 right-1">
                        <Sparkles className="h-3 w-3 text-purple-500" />
                      </span>
                    )}
                  </button>
                </PopoverTrigger>
                <PopoverContent className="w-72 p-0" align="start">
                  <div className="p-3">
                    <div className="flex items-center justify-between mb-2">
                      <p className="font-semibold text-sm">
                        {format(day, "EEEE, dd MMM")}
                      </p>
                      {isVacation && (
                        <Badge variant="outline" className="text-xs">
                          <Palmtree className="h-3 w-3 mr-1" />
                          Vacation
                        </Badge>
                      )}
                    </div>

                    {delivery ? (
                      <div className="space-y-2">
                        <div className="flex items-center gap-2">
                          <Badge
                            variant={
                              delivery.status === "delivered"
                                ? "default"
                                : delivery.status === "missed"
                                ? "destructive"
                                : "secondary"
                            }
                          >
                            {delivery.status}
                          </Badge>
                          {delivery.delivery_time && (
                            <span className="text-xs text-muted-foreground">
                              {format(new Date(delivery.delivery_time), "hh:mm a")}
                            </span>
                          )}
                        </div>

                        <ScrollArea className="h-[120px]">
                          <div className="space-y-1">
                            {delivery.items.map((item) => {
                              const isAddOn = !activeSubscriptions.find(
                                (s) => s.product_name === item.product_name
                              );
                              const sub = activeSubscriptions.find(
                                (s) => s.product_name === item.product_name
                              );
                              const isModified = sub && sub.quantity !== item.quantity;

                              return (
                                <div
                                  key={item.id}
                                  className={cn(
                                    "flex items-center justify-between text-xs p-1.5 rounded",
                                    isAddOn
                                      ? "bg-purple-50 dark:bg-purple-900/20"
                                      : isModified
                                      ? "bg-amber-50 dark:bg-amber-900/20"
                                      : "bg-muted/50"
                                  )}
                                >
                                  <div className="flex items-center gap-1">
                                    {isAddOn && (
                                      <Sparkles className="h-3 w-3 text-purple-500" />
                                    )}
                                    <span>{item.product_name}</span>
                                    <span className="text-muted-foreground">
                                      × {item.quantity}
                                    </span>
                                  </div>
                                  <span className="font-medium">
                                    ₹{item.total_amount.toLocaleString()}
                                  </span>
                                </div>
                              );
                            })}
                          </div>
                        </ScrollArea>

                        <div className="flex justify-between items-center pt-2 border-t">
                          <span className="text-xs text-muted-foreground">Total</span>
                          <span className="font-bold">
                            ₹
                            {delivery.items
                              .reduce((sum, item) => sum + item.total_amount, 0)
                              .toLocaleString()}
                          </span>
                        </div>

                        {delivery.notes && (
                          <p className="text-xs text-muted-foreground pt-1 border-t">
                            Note: {delivery.notes}
                          </p>
                        )}
                      </div>
                    ) : isVacation ? (
                      <p className="text-xs text-muted-foreground">
                        Delivery paused - Customer on vacation
                      </p>
                    ) : isExpected ? (
                      <div className="space-y-2">
                        <p className="text-xs text-muted-foreground">
                          Expected subscription delivery:
                        </p>
                        <div className="space-y-1">
                          {activeSubscriptions.map((sub) => (
                            <div
                              key={sub.id}
                              className="flex justify-between text-xs bg-muted/50 p-1.5 rounded"
                            >
                              <span>
                                {sub.product_name} × {sub.quantity}
                              </span>
                              <span className="text-muted-foreground">
                                ₹
                                {(
                                  (sub.custom_price ?? sub.base_price) *
                                  sub.quantity
                                ).toLocaleString()}
                              </span>
                            </div>
                          ))}
                        </div>
                        <div className="flex justify-between items-center pt-2 border-t">
                          <span className="text-xs text-muted-foreground">
                            Expected Total
                          </span>
                          <span className="font-medium text-muted-foreground">
                            ₹{dailySubscriptionValue.toLocaleString()}
                          </span>
                        </div>
                      </div>
                    ) : (
                      <p className="text-xs text-muted-foreground">
                        No delivery scheduled ({subscriptionType} subscription)
                      </p>
                    )}
                  </div>
                </PopoverContent>
              </Popover>
            );
          })}
        </div>

        {/* Legend */}
        <div className="flex flex-wrap gap-3 mt-4 pt-3 border-t text-xs">
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-green-100 dark:bg-green-900/30" />
            <span className="text-muted-foreground">Delivered</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-red-100 dark:bg-red-900/30" />
            <span className="text-muted-foreground">Missed</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-blue-100 dark:bg-blue-900/30" />
            <span className="text-muted-foreground">Pending</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-amber-100 dark:bg-amber-900/30" />
            <span className="text-muted-foreground">Vacation</span>
          </div>
          <div className="flex items-center gap-1">
            <Sparkles className="h-3 w-3 text-purple-500" />
            <span className="text-muted-foreground">Add-on</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
