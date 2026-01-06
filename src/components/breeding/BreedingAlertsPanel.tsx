import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Button } from "@/components/ui/button";
import { 
  AlertTriangle, 
  Bell, 
  Syringe, 
  Heart, 
  Baby, 
  Stethoscope,
  Droplets,
  Calendar,
  ChevronRight
} from "lucide-react";
import { cn } from "@/lib/utils";
import { BreedingAlert } from "@/hooks/useBreedingAlerts";
import { format } from "date-fns";

interface BreedingAlertsPanelProps {
  alerts: BreedingAlert[];
  criticalCount: number;
  warningCount: number;
  upcomingCount: number;
  maxItems?: number;
  showViewAll?: boolean;
  onViewAll?: () => void;
}

const categoryIcons = {
  heat_cycle: Heart,
  vaccination: Syringe,
  calving: Baby,
  health_check: Stethoscope,
  insemination: Droplets,
  dry_off: AlertTriangle,
};

const categoryLabels = {
  heat_cycle: "Heat Cycle",
  vaccination: "Vaccination",
  calving: "Calving",
  health_check: "Health Check",
  insemination: "AI Follow-up",
  dry_off: "Dry-Off",
};

const typeStyles = {
  warning: "border-l-warning bg-warning/5",
  error: "border-l-destructive bg-destructive/5",
  info: "border-l-info bg-info/5",
};

const badgeVariants = {
  warning: "bg-warning/20 text-warning hover:bg-warning/30",
  error: "bg-destructive/20 text-destructive hover:bg-destructive/30",
  info: "bg-info/20 text-info hover:bg-info/30",
};

export function BreedingAlertsPanel({
  alerts,
  criticalCount,
  warningCount,
  upcomingCount,
  maxItems = 10,
  showViewAll = false,
  onViewAll,
}: BreedingAlertsPanelProps) {
  const displayedAlerts = alerts.slice(0, maxItems);
  const hasMore = alerts.length > maxItems;

  if (alerts.length === 0) {
    return (
      <Card className="h-full">
        <CardHeader className="pb-3">
          <CardTitle className="flex items-center gap-2 text-lg font-semibold">
            <Bell className="h-5 w-5 text-muted-foreground" />
            Breeding Alerts
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col items-center justify-center py-8 text-center text-muted-foreground">
            <Calendar className="h-12 w-12 mb-3 opacity-50" />
            <p className="text-sm">No upcoming alerts</p>
            <p className="text-xs mt-1">All breeding events are up to date</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="h-full">
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center justify-between">
          <div className="flex items-center gap-2 text-lg font-semibold">
            <Bell className="h-5 w-5 text-destructive" />
            Breeding Alerts
          </div>
          <div className="flex gap-2">
            {criticalCount > 0 && (
              <Badge variant="destructive" className="text-xs">
                {criticalCount} Critical
              </Badge>
            )}
            {warningCount > 0 && (
              <Badge className="bg-warning/20 text-warning hover:bg-warning/30 text-xs">
                {warningCount} Warning
              </Badge>
            )}
            {upcomingCount > 0 && (
              <Badge variant="secondary" className="text-xs">
                {upcomingCount} Upcoming
              </Badge>
            )}
          </div>
        </CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <ScrollArea className="h-[400px] px-6">
          <div className="space-y-2 pb-4">
            {displayedAlerts.map((alert, index) => {
              const Icon = categoryIcons[alert.category];
              return (
                <div
                  key={alert.id}
                  className={cn(
                    "rounded-lg border-l-4 p-3 transition-colors hover:bg-muted/30",
                    typeStyles[alert.type],
                    "animate-slide-in-left"
                  )}
                  style={{ animationDelay: `${index * 30}ms` }}
                >
                  <div className="flex items-start gap-3">
                    <div className={cn(
                      "mt-0.5 rounded-full p-1.5",
                      alert.type === "error" && "bg-destructive/20",
                      alert.type === "warning" && "bg-warning/20",
                      alert.type === "info" && "bg-info/20"
                    )}>
                      <Icon className={cn(
                        "h-4 w-4",
                        alert.type === "error" && "text-destructive",
                        alert.type === "warning" && "text-warning",
                        alert.type === "info" && "text-info"
                      )} />
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <p className="text-sm font-medium text-foreground">{alert.title}</p>
                        <Badge 
                          variant="outline" 
                          className={cn("text-[10px]", badgeVariants[alert.type])}
                        >
                          {categoryLabels[alert.category]}
                        </Badge>
                      </div>
                      <p className="mt-0.5 text-xs text-muted-foreground">{alert.description}</p>
                      <div className="mt-1.5 flex items-center gap-2 text-[10px] text-muted-foreground">
                        <Calendar className="h-3 w-3" />
                        <span>{format(alert.dueDate, "MMM d, yyyy")}</span>
                        <span className="text-muted-foreground/50">•</span>
                        <span className={cn(
                          "font-medium",
                          alert.daysUntil <= 0 && "text-destructive",
                          alert.daysUntil > 0 && alert.daysUntil <= 3 && "text-warning",
                          alert.daysUntil > 3 && "text-info"
                        )}>
                          {alert.daysUntil === 0 
                            ? "Today" 
                            : alert.daysUntil < 0 
                            ? `${Math.abs(alert.daysUntil)}d overdue` 
                            : `${alert.daysUntil}d remaining`}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </ScrollArea>
        {(hasMore || showViewAll) && (
          <div className="border-t p-3">
            <Button 
              variant="ghost" 
              className="w-full text-sm"
              onClick={onViewAll}
            >
              View All {alerts.length} Alerts
              <ChevronRight className="ml-2 h-4 w-4" />
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
