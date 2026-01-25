import { useState, useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Plus, Minus, Milk, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface Product {
  id: string;
  name: string;
  category: string;
  unit: string;
  base_price: number;
}

interface SubscriptionProduct {
  product_id: string;
  product_name: string;
  quantity: number;
  custom_price: number | null;
  unit: string;
}

interface DeliveryDays {
  monday: boolean;
  tuesday: boolean;
  wednesday: boolean;
  thursday: boolean;
  friday: boolean;
  saturday: boolean;
  sunday: boolean;
}

export interface CustomerSubscriptionData {
  products: SubscriptionProduct[];
  frequency: "daily" | "alternate" | "weekly" | "custom";
  delivery_days: DeliveryDays;
  auto_deliver: boolean;
}

interface CustomerSubscriptionSelectorProps {
  value: CustomerSubscriptionData;
  onChange: (data: CustomerSubscriptionData) => void;
}

const defaultDeliveryDays: DeliveryDays = {
  monday: true,
  tuesday: true,
  wednesday: true,
  thursday: true,
  friday: true,
  saturday: true,
  sunday: true,
};

const weekDays = [
  { key: "monday", label: "Mon" },
  { key: "tuesday", label: "Tue" },
  { key: "wednesday", label: "Wed" },
  { key: "thursday", label: "Thu" },
  { key: "friday", label: "Fri" },
  { key: "saturday", label: "Sat" },
  { key: "sunday", label: "Sun" },
] as const;

export function CustomerSubscriptionSelector({
  value,
  onChange,
}: CustomerSubscriptionSelectorProps) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    const { data, error } = await supabase
      .from("products")
      .select("id, name, category, unit, base_price")
      .eq("is_active", true)
      .order("category")
      .order("name");

    if (!error && data) {
      setProducts(data);
    }
    setLoading(false);
  };

  const handleProductToggle = (product: Product) => {
    const existing = value.products.find((p) => p.product_id === product.id);
    if (existing) {
      // Remove product
      onChange({
        ...value,
        products: value.products.filter((p) => p.product_id !== product.id),
      });
    } else {
      // Add product with default quantity of 1
      onChange({
        ...value,
        products: [
          ...value.products,
          {
            product_id: product.id,
            product_name: product.name,
            quantity: 1,
            custom_price: null,
            unit: product.unit,
          },
        ],
      });
    }
  };

  const updateQuantity = (productId: string, delta: number) => {
    onChange({
      ...value,
      products: value.products.map((p) => {
        if (p.product_id === productId) {
          const newQty = Math.max(0.25, p.quantity + delta);
          return { ...p, quantity: newQty };
        }
        return p;
      }),
    });
  };

  const setQuantity = (productId: string, qty: number) => {
    onChange({
      ...value,
      products: value.products.map((p) => {
        if (p.product_id === productId) {
          return { ...p, quantity: Math.max(0.25, qty) };
        }
        return p;
      }),
    });
  };

  const handleFrequencyChange = (frequency: typeof value.frequency) => {
    let newDeliveryDays = { ...value.delivery_days };

    // Pre-configure delivery days based on frequency
    if (frequency === "daily") {
      newDeliveryDays = { ...defaultDeliveryDays };
    } else if (frequency === "alternate") {
      // Mon, Wed, Fri, Sun
      newDeliveryDays = {
        monday: true,
        tuesday: false,
        wednesday: true,
        thursday: false,
        friday: true,
        saturday: false,
        sunday: true,
      };
    } else if (frequency === "weekly") {
      // Only Sunday
      newDeliveryDays = {
        monday: false,
        tuesday: false,
        wednesday: false,
        thursday: false,
        friday: false,
        saturday: false,
        sunday: true,
      };
    }

    onChange({
      ...value,
      frequency,
      delivery_days: newDeliveryDays,
    });
  };

  const toggleDeliveryDay = (day: keyof DeliveryDays) => {
    onChange({
      ...value,
      delivery_days: {
        ...value.delivery_days,
        [day]: !value.delivery_days[day],
      },
    });
  };

  const selectedProductIds = new Set(value.products.map((p) => p.product_id));

  const groupedProducts = products.reduce((acc, product) => {
    if (!acc[product.category]) {
      acc[product.category] = [];
    }
    acc[product.category].push(product);
    return acc;
  }, {} as Record<string, Product[]>);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  const totalMonthlyValue = value.products.reduce((sum, p) => {
    const product = products.find((pr) => pr.id === p.product_id);
    const price = p.custom_price ?? product?.base_price ?? 0;
    const deliveryDaysCount = Object.values(value.delivery_days).filter(Boolean).length;
    const daysPerMonth = (deliveryDaysCount / 7) * 30;
    return sum + price * p.quantity * daysPerMonth;
  }, 0);

  return (
    <div className="space-y-4">
      {/* Subscription Products */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <Milk className="h-4 w-4" />
            Select Products
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {Object.entries(groupedProducts).map(([category, categoryProducts]) => (
            <div key={category} className="space-y-2">
              <Label className="text-xs uppercase text-muted-foreground">
                {category}
              </Label>
              <div className="grid gap-2 sm:grid-cols-2">
                {categoryProducts.map((product) => {
                  const isSelected = selectedProductIds.has(product.id);
                  const selectedProduct = value.products.find(
                    (p) => p.product_id === product.id
                  );

                  return (
                    <div
                      key={product.id}
                      className={cn(
                        "flex items-center justify-between p-3 rounded-lg border cursor-pointer transition-colors",
                        isSelected
                          ? "bg-primary/5 border-primary"
                          : "hover:bg-muted/50"
                      )}
                      onClick={() => handleProductToggle(product)}
                    >
                      <div className="flex items-center gap-3">
                        <Checkbox checked={isSelected} />
                        <div>
                          <p className="font-medium text-sm">{product.name}</p>
                          <p className="text-xs text-muted-foreground">
                            ₹{product.base_price}/{product.unit}
                          </p>
                        </div>
                      </div>

                      {isSelected && selectedProduct && (
                        <div
                          className="flex items-center gap-1"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <Button
                            variant="outline"
                            size="icon"
                            className="h-7 w-7"
                            onClick={() => updateQuantity(product.id, -0.5)}
                          >
                            <Minus className="h-3 w-3" />
                          </Button>
                          <Input
                            type="number"
                            step="0.25"
                            min="0.25"
                            value={selectedProduct.quantity}
                            onChange={(e) =>
                              setQuantity(product.id, parseFloat(e.target.value) || 0.25)
                            }
                            className="h-7 w-16 text-center"
                          />
                          <Button
                            variant="outline"
                            size="icon"
                            className="h-7 w-7"
                            onClick={() => updateQuantity(product.id, 0.5)}
                          >
                            <Plus className="h-3 w-3" />
                          </Button>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          ))}

          {products.length === 0 && (
            <p className="text-sm text-muted-foreground text-center py-4">
              No products available. Add products first.
            </p>
          )}
        </CardContent>
      </Card>

      {/* Delivery Frequency */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium">Delivery Schedule</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label>Frequency</Label>
            <Select
              value={value.frequency}
              onValueChange={(v) =>
                handleFrequencyChange(v as typeof value.frequency)
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="daily">Daily</SelectItem>
                <SelectItem value="alternate">Alternate Days</SelectItem>
                <SelectItem value="weekly">Weekly</SelectItem>
                <SelectItem value="custom">Custom Days</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Delivery Days Selector */}
          <div className="space-y-2">
            <Label>Delivery Days</Label>
            <div className="flex flex-wrap gap-2">
              {weekDays.map((day) => (
                <Badge
                  key={day.key}
                  variant={value.delivery_days[day.key] ? "default" : "outline"}
                  className={cn(
                    "cursor-pointer transition-colors",
                    value.delivery_days[day.key]
                      ? "bg-primary hover:bg-primary/80"
                      : "hover:bg-muted"
                  )}
                  onClick={() => toggleDeliveryDay(day.key)}
                >
                  {day.label}
                </Badge>
              ))}
            </div>
          </div>

          {/* Auto-Deliver Toggle */}
          <div className="flex items-center justify-between pt-2 border-t">
            <div>
              <p className="text-sm font-medium">Auto-mark as Delivered</p>
              <p className="text-xs text-muted-foreground">
                Automatically mark deliveries as completed daily
              </p>
            </div>
            <Checkbox
              checked={value.auto_deliver}
              onCheckedChange={(checked) =>
                onChange({ ...value, auto_deliver: !!checked })
              }
            />
          </div>
        </CardContent>
      </Card>

      {/* Summary */}
      {value.products.length > 0 && (
        <Card className="bg-muted/50">
          <CardContent className="pt-4">
            <div className="flex justify-between items-center">
              <div>
                <p className="text-sm font-medium">
                  {value.products.length} product{value.products.length !== 1 ? "s" : ""} selected
                </p>
                <p className="text-xs text-muted-foreground">
                  {Object.values(value.delivery_days).filter(Boolean).length} days/week
                </p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold text-primary">
                  ≈ ₹{Math.round(totalMonthlyValue).toLocaleString()}
                </p>
                <p className="text-xs text-muted-foreground">Est. monthly value</p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

export const defaultSubscriptionData: CustomerSubscriptionData = {
  products: [],
  frequency: "daily",
  delivery_days: defaultDeliveryDays,
  auto_deliver: true,
};
