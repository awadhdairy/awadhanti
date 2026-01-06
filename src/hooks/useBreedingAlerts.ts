import { useMemo } from "react";
import { addDays, differenceInDays, isAfter, isBefore, parseISO, format } from "date-fns";

interface BreedingRecord {
  id: string;
  cattle_id: string;
  record_type: string;
  record_date: string;
  expected_calving_date?: string | null;
  heat_cycle_day?: number | null;
  pregnancy_confirmed?: boolean | null;
}

interface HealthRecord {
  id: string;
  cattle_id: string;
  record_type: string;
  title: string;
  next_due_date?: string | null;
}

interface Cattle {
  id: string;
  tag_number: string;
  name?: string | null;
  status?: string | null;
  lactation_status?: string | null;
}

export interface BreedingAlert {
  id: string;
  type: "warning" | "error" | "info";
  category: "heat_cycle" | "vaccination" | "calving" | "health_check" | "insemination" | "dry_off";
  title: string;
  description: string;
  dueDate: Date;
  daysUntil: number;
  cattleId: string;
  cattleTag: string;
  cattleName?: string;
  priority: number; // Lower is higher priority
}

const HEAT_CYCLE_LENGTH = 21; // Days between heat cycles
const GESTATION_PERIOD = 283; // Days for cow pregnancy
const DRY_OFF_BEFORE_CALVING = 60; // Days before calving to dry off

export function useBreedingAlerts(
  breedingRecords: BreedingRecord[],
  healthRecords: HealthRecord[],
  cattle: Cattle[]
): { alerts: BreedingAlert[]; criticalCount: number; warningCount: number; upcomingCount: number } {
  const cattleMap = useMemo(() => {
    const map = new Map<string, Cattle>();
    cattle.forEach((c) => map.set(c.id, c));
    return map;
  }, [cattle]);

  const alerts = useMemo(() => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const alertsList: BreedingAlert[] = [];

    // Process breeding records for heat cycles and calving alerts
    breedingRecords.forEach((record) => {
      const cattleInfo = cattleMap.get(record.cattle_id);
      if (!cattleInfo || cattleInfo.status !== "active") return;

      const cattleTag = cattleInfo.tag_number;
      const cattleName = cattleInfo.name || undefined;

      // Expected Calving Alerts
      if (record.expected_calving_date && record.pregnancy_confirmed) {
        const calvingDate = parseISO(record.expected_calving_date);
        const daysUntil = differenceInDays(calvingDate, today);

        if (daysUntil >= -7 && daysUntil <= 30) {
          let alertType: "warning" | "error" | "info" = "info";
          let priority = 3;

          if (daysUntil <= 0) {
            alertType = "error";
            priority = 1;
          } else if (daysUntil <= 7) {
            alertType = "warning";
            priority = 2;
          }

          alertsList.push({
            id: `calving-${record.id}`,
            type: alertType,
            category: "calving",
            title: daysUntil <= 0 ? "Calving Overdue/Due Today" : "Upcoming Calving",
            description: `${cattleTag}${cattleName ? ` (${cattleName})` : ""} expected to calve ${
              daysUntil === 0 ? "today" : daysUntil < 0 ? `${Math.abs(daysUntil)} days ago` : `in ${daysUntil} days`
            }`,
            dueDate: calvingDate,
            daysUntil,
            cattleId: record.cattle_id,
            cattleTag,
            cattleName,
            priority,
          });

          // Dry-off reminder (60 days before calving)
          const dryOffDate = addDays(calvingDate, -DRY_OFF_BEFORE_CALVING);
          const daysUntilDryOff = differenceInDays(dryOffDate, today);

          if (daysUntilDryOff >= -3 && daysUntilDryOff <= 14 && cattleInfo.lactation_status === "lactating") {
            alertsList.push({
              id: `dryoff-${record.id}`,
              type: daysUntilDryOff <= 0 ? "error" : daysUntilDryOff <= 7 ? "warning" : "info",
              category: "dry_off",
              title: "Dry-Off Required",
              description: `${cattleTag}${cattleName ? ` (${cattleName})` : ""} should be dried off ${
                daysUntilDryOff === 0 ? "today" : daysUntilDryOff < 0 ? `${Math.abs(daysUntilDryOff)} days ago` : `in ${daysUntilDryOff} days`
              }`,
              dueDate: dryOffDate,
              daysUntil: daysUntilDryOff,
              cattleId: record.cattle_id,
              cattleTag,
              cattleName,
              priority: daysUntilDryOff <= 0 ? 1 : 2,
            });
          }
        }
      }

      // Heat Cycle Predictions (for non-pregnant cattle after heat detection)
      if (record.record_type === "heat_detection" && !record.pregnancy_confirmed) {
        const lastHeatDate = parseISO(record.record_date);
        const nextHeatDate = addDays(lastHeatDate, HEAT_CYCLE_LENGTH);
        const daysUntil = differenceInDays(nextHeatDate, today);

        // Show alert 3 days before to 2 days after expected heat
        if (daysUntil >= -2 && daysUntil <= 5) {
          alertsList.push({
            id: `heat-${record.id}`,
            type: daysUntil <= 0 ? "error" : daysUntil <= 2 ? "warning" : "info",
            category: "heat_cycle",
            title: daysUntil <= 0 ? "Heat Expected Now" : "Upcoming Heat Cycle",
            description: `${cattleTag}${cattleName ? ` (${cattleName})` : ""} expected in heat ${
              daysUntil === 0 ? "today" : daysUntil < 0 ? `${Math.abs(daysUntil)} days ago` : `in ${daysUntil} days`
            }`,
            dueDate: nextHeatDate,
            daysUntil,
            cattleId: record.cattle_id,
            cattleTag,
            cattleName,
            priority: daysUntil <= 0 ? 1 : 2,
          });
        }
      }

      // Follow-up insemination check (for AI records without pregnancy confirmation)
      if (record.record_type === "artificial_insemination" && record.pregnancy_confirmed === null) {
        const inseminationDate = parseISO(record.record_date);
        const pregnancyCheckDate = addDays(inseminationDate, 21); // Check pregnancy ~21 days after AI
        const daysUntil = differenceInDays(pregnancyCheckDate, today);

        if (daysUntil >= -3 && daysUntil <= 7) {
          alertsList.push({
            id: `preg-check-${record.id}`,
            type: daysUntil <= 0 ? "warning" : "info",
            category: "insemination",
            title: "Pregnancy Check Due",
            description: `${cattleTag}${cattleName ? ` (${cattleName})` : ""} needs pregnancy check ${
              daysUntil === 0 ? "today" : daysUntil < 0 ? `${Math.abs(daysUntil)} days overdue` : `in ${daysUntil} days`
            }`,
            dueDate: pregnancyCheckDate,
            daysUntil,
            cattleId: record.cattle_id,
            cattleTag,
            cattleName,
            priority: daysUntil <= 0 ? 2 : 3,
          });
        }
      }
    });

    // Process health records for vaccination and health check alerts
    healthRecords.forEach((record) => {
      if (!record.next_due_date) return;

      const cattleInfo = cattleMap.get(record.cattle_id);
      if (!cattleInfo || cattleInfo.status !== "active") return;

      const cattleTag = cattleInfo.tag_number;
      const cattleName = cattleInfo.name || undefined;

      const dueDate = parseISO(record.next_due_date);
      const daysUntil = differenceInDays(dueDate, today);

      // Show vaccination alerts 14 days before to 7 days after due date
      if (daysUntil >= -7 && daysUntil <= 14) {
        const isVaccination = record.record_type === "vaccination";

        alertsList.push({
          id: `health-${record.id}`,
          type: daysUntil <= 0 ? "error" : daysUntil <= 3 ? "warning" : "info",
          category: isVaccination ? "vaccination" : "health_check",
          title: isVaccination
            ? daysUntil <= 0
              ? "Vaccination Overdue"
              : "Vaccination Due"
            : daysUntil <= 0
            ? "Health Check Overdue"
            : "Health Check Due",
          description: `${cattleTag}${cattleName ? ` (${cattleName})` : ""}: ${record.title} ${
            daysUntil === 0 ? "due today" : daysUntil < 0 ? `${Math.abs(daysUntil)} days overdue` : `due in ${daysUntil} days`
          }`,
          dueDate,
          daysUntil,
          cattleId: record.cattle_id,
          cattleTag,
          cattleName,
          priority: daysUntil <= 0 ? 1 : daysUntil <= 3 ? 2 : 3,
        });
      }
    });

    // Sort by priority (lower first), then by days until (closer first)
    return alertsList.sort((a, b) => {
      if (a.priority !== b.priority) return a.priority - b.priority;
      return a.daysUntil - b.daysUntil;
    });
  }, [breedingRecords, healthRecords, cattleMap]);

  const criticalCount = alerts.filter((a) => a.type === "error").length;
  const warningCount = alerts.filter((a) => a.type === "warning").length;
  const upcomingCount = alerts.filter((a) => a.type === "info").length;

  return { alerts, criticalCount, warningCount, upcomingCount };
}
