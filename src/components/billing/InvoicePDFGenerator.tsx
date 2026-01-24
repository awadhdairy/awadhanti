import { useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import { format } from "date-fns";
import { Button } from "@/components/ui/button";
import { Download, Loader2, Eye } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { numberToIndianWords } from "@/lib/numberToWords";
import { logger } from "@/lib/logger";

interface DairySettings {
  dairy_name: string;
  address: string | null;
  phone: string | null;
  email: string | null;
  currency: string;
  invoice_prefix: string;
}

interface Customer {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  area: string | null;
}

interface DeliveryItem {
  product_name: string;
  quantity: number;
  unit_price: number;
  total_amount: number;
  delivery_date: string;
  unit: string;
}

// Type for Supabase delivery query result
interface DeliveryQueryResult {
  delivery_date: string;
  delivery_items: Array<{
    quantity: number;
    unit_price: number;
    total_amount: number;
    product: { name: string; unit: string } | null;
  }> | null;
}

interface Invoice {
  id: string;
  invoice_number: string;
  customer_id: string;
  billing_period_start: string;
  billing_period_end: string;
  total_amount: number;
  tax_amount: number;
  discount_amount: number;
  final_amount: number;
  paid_amount: number;
  payment_status: string;
  due_date: string | null;
  created_at: string;
  notes?: string | null;
  customer?: {
    id: string;
    name: string;
  };
}

interface InvoicePDFGeneratorProps {
  invoice: Invoice;
  onGenerated?: () => void;
}

export function InvoicePDFGenerator({ invoice, onGenerated }: InvoicePDFGeneratorProps) {
  const [generating, setGenerating] = useState(false);
  const [previewOpen, setPreviewOpen] = useState(false);
  const [pdfDataUrl, setPdfDataUrl] = useState<string | null>(null);

  const generatePDF = async (action: "download" | "preview" = "download") => {
    setGenerating(true);

    try {
      // Fetch dairy settings
      const { data: settingsData } = await supabase
        .from("dairy_settings")
        .select("*")
        .limit(1)
        .single();

      const settings: DairySettings = settingsData || {
        dairy_name: "Awadh Dairy",
        address: "Fresh Quality Dairy Products",
        phone: "+91 9876543210",
        email: "contact@awadhdairy.com",
        currency: "INR",
        invoice_prefix: "INV",
      };

      // Fetch customer details
      const { data: customerData } = await supabase
        .from("customers")
        .select("*")
        .eq("id", invoice.customer_id)
        .single();

      const customer: Customer = customerData || {
        id: invoice.customer_id,
        name: invoice.customer?.name || "Customer",
        phone: null,
        email: null,
        address: null,
        area: null,
      };

      // Fetch delivery items for this billing period
      const { data: deliveries } = await supabase
        .from("deliveries")
        .select(`
          delivery_date,
          delivery_items (
            quantity,
            unit_price,
            total_amount,
            product:product_id (name, unit)
          )
        `)
        .eq("customer_id", invoice.customer_id)
        .gte("delivery_date", invoice.billing_period_start)
        .lte("delivery_date", invoice.billing_period_end)
        .eq("status", "delivered");

      // Flatten delivery items with proper typing
      const items: DeliveryItem[] = [];
      const typedDeliveries = (deliveries || []) as DeliveryQueryResult[];
      typedDeliveries.forEach((delivery) => {
        (delivery.delivery_items || []).forEach((item) => {
          items.push({
            product_name: item.product?.name || "Product",
            quantity: item.quantity,
            unit_price: item.unit_price,
            total_amount: item.total_amount,
            delivery_date: delivery.delivery_date,
            unit: item.product?.unit || "unit",
          });
        });
      });

      // Create PDF
      const doc = new jsPDF({
        orientation: "portrait",
        unit: "mm",
        format: "a4",
      });

      const pageWidth = doc.internal.pageSize.getWidth();
      const pageHeight = doc.internal.pageSize.getHeight();
      const margin = 15;

      // Colors - Professional theme
      const primaryColor: [number, number, number] = [45, 90, 39]; // Dark green
      const secondaryColor: [number, number, number] = [76, 175, 80]; // Light green
      const accentColor: [number, number, number] = [255, 193, 7]; // Amber
      const darkColor: [number, number, number] = [33, 33, 33]; // Near black
      const lightBg: [number, number, number] = [245, 245, 245]; // Light gray
      const whiteBg: [number, number, number] = [255, 255, 255];

      // Header background
      doc.setFillColor(...primaryColor);
      doc.rect(0, 0, pageWidth, 50, "F");
      
      // Accent stripe
      doc.setFillColor(...secondaryColor);
      doc.rect(0, 50, pageWidth, 4, "F");

      // Company name - Large and prominent
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(28);
      doc.setFont("helvetica", "bold");
      doc.text(settings.dairy_name, margin, 22);

      // Tagline
      doc.setFontSize(10);
      doc.setFont("helvetica", "normal");
      doc.text("Premium Quality Fresh Dairy Products", margin, 32);

      // Contact info line
      doc.setFontSize(8);
      const contactInfo: string[] = [];
      if (settings.phone) contactInfo.push(`📞 ${settings.phone}`);
      contactInfo.push("📧 contact@awadhdairy.com");
      contactInfo.push("🌐 www.awadhdairy.com");
      if (settings.address) contactInfo.push(`📍 ${settings.address}`);
      doc.text(contactInfo.join("  |  "), margin, 42);

      // Invoice badge - Right side
      doc.setFillColor(...whiteBg);
      doc.roundedRect(pageWidth - margin - 60, 10, 60, 34, 3, 3, "F");
      
      doc.setTextColor(...primaryColor);
      doc.setFontSize(16);
      doc.setFont("helvetica", "bold");
      doc.text("TAX INVOICE", pageWidth - margin - 30, 22, { align: "center" });
      
      doc.setTextColor(...darkColor);
      doc.setFontSize(11);
      doc.setFont("helvetica", "bold");
      doc.text(invoice.invoice_number, pageWidth - margin - 30, 32, { align: "center" });
      
      doc.setFontSize(8);
      doc.setFont("helvetica", "normal");
      doc.text(format(new Date(invoice.created_at), "dd MMM yyyy"), pageWidth - margin - 30, 40, { align: "center" });

      // Main content starts
      let yPos = 65;

      // Two-column layout for Bill To and Invoice Details
      const colWidth = (pageWidth - margin * 2 - 15) / 2;

      // Left Column - BILL TO
      doc.setFillColor(...lightBg);
      doc.roundedRect(margin, yPos, colWidth, 48, 3, 3, "F");
      
      doc.setTextColor(...primaryColor);
      doc.setFontSize(10);
      doc.setFont("helvetica", "bold");
      doc.text("BILL TO", margin + 8, yPos + 10);
      
      doc.setDrawColor(...secondaryColor);
      doc.setLineWidth(0.5);
      doc.line(margin + 8, yPos + 13, margin + 40, yPos + 13);
      
      doc.setTextColor(...darkColor);
      doc.setFontSize(12);
      doc.setFont("helvetica", "bold");
      doc.text(customer.name, margin + 8, yPos + 22);
      
      doc.setFont("helvetica", "normal");
      doc.setFontSize(9);
      let customerY = yPos + 28;
      if (customer.address) {
        doc.text(customer.address, margin + 8, customerY);
        customerY += 5;
      }
      if (customer.area) {
        doc.text(`Area: ${customer.area}`, margin + 8, customerY);
        customerY += 5;
      }
      if (customer.phone) {
        doc.text(`Phone: ${customer.phone}`, margin + 8, customerY);
        customerY += 5;
      }
      if (customer.email) {
        doc.text(`Email: ${customer.email}`, margin + 8, customerY);
      }

      // Right Column - INVOICE DETAILS
      const rightColX = margin + colWidth + 15;
      doc.setFillColor(...lightBg);
      doc.roundedRect(rightColX, yPos, colWidth, 48, 3, 3, "F");

      doc.setTextColor(...primaryColor);
      doc.setFontSize(10);
      doc.setFont("helvetica", "bold");
      doc.text("INVOICE DETAILS", rightColX + 8, yPos + 10);
      
      doc.setDrawColor(...secondaryColor);
      doc.line(rightColX + 8, yPos + 13, rightColX + 55, yPos + 13);

      doc.setTextColor(...darkColor);
      doc.setFontSize(9);
      
      const labelX = rightColX + 8;
      const valueX = rightColX + colWidth - 8;
      let detailY = yPos + 22;

      doc.setFont("helvetica", "bold");
      doc.text("Invoice Date:", labelX, detailY);
      doc.setFont("helvetica", "normal");
      doc.text(format(new Date(invoice.created_at), "dd MMMM yyyy"), valueX, detailY, { align: "right" });

      detailY += 7;
      doc.setFont("helvetica", "bold");
      doc.text("Billing Period:", labelX, detailY);
      doc.setFont("helvetica", "normal");
      doc.text(
        `${format(new Date(invoice.billing_period_start), "dd MMM")} - ${format(new Date(invoice.billing_period_end), "dd MMM yyyy")}`,
        valueX, detailY, { align: "right" }
      );

      detailY += 7;
      doc.setFont("helvetica", "bold");
      doc.text("Due Date:", labelX, detailY);
      doc.setFont("helvetica", "normal");
      doc.text(
        invoice.due_date ? format(new Date(invoice.due_date), "dd MMMM yyyy") : "On Receipt",
        valueX, detailY, { align: "right" }
      );

      // Status badge
      detailY += 10;
      const statusText = invoice.payment_status.toUpperCase();
      let statusColor: [number, number, number];
      switch (invoice.payment_status) {
        case "paid":
          statusColor = [16, 185, 129];
          break;
        case "partial":
          statusColor = [245, 158, 11];
          break;
        case "overdue":
          statusColor = [239, 68, 68];
          break;
        default:
          statusColor = [100, 116, 139];
      }
      
      doc.setFillColor(...statusColor);
      doc.roundedRect(labelX, detailY - 5, 40, 10, 2, 2, "F");
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(9);
      doc.setFont("helvetica", "bold");
      doc.text(statusText, labelX + 20, detailY + 1, { align: "center" });

      yPos += 58;

      // Items table with Rate and Quantity columns
      if (items.length > 0) {
        // Group items by product and calculate totals
        const groupedItems = items.reduce((acc: Record<string, {
          product_name: string;
          unit: string;
          quantity: number;
          unit_price: number;
          total_amount: number;
        }>, item) => {
          const key = `${item.product_name}_${item.unit_price}`;
          if (!acc[key]) {
            acc[key] = {
              product_name: item.product_name,
              unit: item.unit,
              quantity: 0,
              unit_price: item.unit_price,
              total_amount: 0,
            };
          }
          acc[key].quantity += item.quantity;
          acc[key].total_amount += item.total_amount;
          return acc;
        }, {});

        const tableData = Object.values(groupedItems).map((item, index) => [
          (index + 1).toString(),
          item.product_name,
          item.quantity.toFixed(2),
          item.unit,
          `₹${item.unit_price.toFixed(2)}`,
          `₹${item.total_amount.toFixed(2)}`,
        ]);

        autoTable(doc, {
          startY: yPos,
          head: [["S.No", "Description", "Qty", "Unit", "Rate", "Amount"]],
          body: tableData,
          margin: { left: margin, right: margin },
          headStyles: {
            fillColor: primaryColor,
            textColor: [255, 255, 255],
            fontStyle: "bold",
            fontSize: 10,
            cellPadding: 5,
            halign: "center",
          },
          bodyStyles: {
            textColor: darkColor,
            fontSize: 9,
            cellPadding: 4,
          },
          alternateRowStyles: {
            fillColor: [250, 250, 250],
          },
          columnStyles: {
            0: { cellWidth: 15, halign: "center" },
            1: { cellWidth: "auto", halign: "left" },
            2: { cellWidth: 22, halign: "right" },
            3: { cellWidth: 20, halign: "center" },
            4: { cellWidth: 30, halign: "right" },
            5: { cellWidth: 32, halign: "right", fontStyle: "bold" },
          },
          styles: {
            lineColor: [200, 200, 200],
            lineWidth: 0.1,
          },
        });

        yPos = (doc as any).lastAutoTable.finalY + 8;
      } else {
        // If no delivery items, show invoice notes if available
        doc.setTextColor(...darkColor);
        doc.setFontSize(10);
        doc.setFont("helvetica", "bold");
        doc.text("Billing Summary", margin, yPos + 5);
        
        yPos += 10;
        
        if (invoice.notes) {
          // Parse the notes which contain item details
          const noteLines = invoice.notes.split("; ");
          const tableData = noteLines.map((line, index) => {
            // Parse format: "Product: quantity unit @ ₹rate/unit"
            const match = line.match(/(.+?):\s*([\d.]+)\s*(\w+)\s*@\s*₹([\d.]+)/);
            if (match) {
              const [, product, qty, unit, rate] = match;
              const amount = parseFloat(qty) * parseFloat(rate);
              return [
                (index + 1).toString(),
                product.trim(),
                parseFloat(qty).toFixed(2),
                unit,
                `₹${parseFloat(rate).toFixed(2)}`,
                `₹${amount.toFixed(2)}`,
              ];
            }
            return [(index + 1).toString(), line, "-", "-", "-", "-"];
          });

          if (tableData.length > 0) {
            autoTable(doc, {
              startY: yPos,
              head: [["S.No", "Description", "Qty", "Unit", "Rate", "Amount"]],
              body: tableData,
              margin: { left: margin, right: margin },
              headStyles: {
                fillColor: primaryColor,
                textColor: [255, 255, 255],
                fontStyle: "bold",
                fontSize: 10,
                cellPadding: 5,
                halign: "center",
              },
              bodyStyles: {
                textColor: darkColor,
                fontSize: 9,
                cellPadding: 4,
              },
              alternateRowStyles: {
                fillColor: [250, 250, 250],
              },
              columnStyles: {
                0: { cellWidth: 15, halign: "center" },
                1: { cellWidth: "auto", halign: "left" },
                2: { cellWidth: 22, halign: "right" },
                3: { cellWidth: 20, halign: "center" },
                4: { cellWidth: 30, halign: "right" },
                5: { cellWidth: 32, halign: "right", fontStyle: "bold" },
              },
            });
            yPos = (doc as any).lastAutoTable.finalY + 8;
          }
        } else {
          // Fallback - simple total display
          doc.setFont("helvetica", "normal");
          doc.setFontSize(9);
          doc.text(`Invoice for billing period: ${format(new Date(invoice.billing_period_start), "dd MMM")} - ${format(new Date(invoice.billing_period_end), "dd MMM yyyy")}`, margin, yPos + 5);
          yPos += 15;
        }
      }

      // Summary section - Right aligned
      const summaryWidth = 90;
      const summaryX = pageWidth - margin - summaryWidth;

      doc.setFillColor(...lightBg);
      doc.roundedRect(summaryX, yPos, summaryWidth, 62, 3, 3, "F");

      const sumLabelX = summaryX + 8;
      const sumValueX = summaryX + summaryWidth - 8;
      let sumY = yPos + 12;

      doc.setFontSize(9);
      doc.setTextColor(...darkColor);
      
      doc.setFont("helvetica", "normal");
      doc.text("Subtotal:", sumLabelX, sumY);
      doc.text(`₹${Number(invoice.total_amount).toFixed(2)}`, sumValueX, sumY, { align: "right" });
      
      sumY += 8;
      doc.text("Tax:", sumLabelX, sumY);
      doc.text(`₹${Number(invoice.tax_amount).toFixed(2)}`, sumValueX, sumY, { align: "right" });
      
      sumY += 8;
      if (Number(invoice.discount_amount) > 0) {
        doc.setTextColor(...secondaryColor);
        doc.text("Discount:", sumLabelX, sumY);
        doc.text(`-₹${Number(invoice.discount_amount).toFixed(2)}`, sumValueX, sumY, { align: "right" });
        sumY += 8;
      }

      // Divider line
      doc.setDrawColor(...primaryColor);
      doc.setLineWidth(0.5);
      doc.line(sumLabelX, sumY, sumValueX, sumY);

      // Grand Total box
      sumY += 6;
      doc.setFillColor(...primaryColor);
      doc.roundedRect(sumLabelX - 4, sumY - 3, summaryWidth - 8, 16, 2, 2, "F");
      
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(10);
      doc.setFont("helvetica", "bold");
      doc.text("GRAND TOTAL", sumLabelX + 2, sumY + 7);
      doc.setFontSize(12);
      doc.text(`₹${Number(invoice.final_amount).toFixed(2)}`, sumValueX - 4, sumY + 7, { align: "right" });

      // Amount in words
      const wordsY = yPos + 70;
      const amountInWords = numberToIndianWords(Number(invoice.final_amount));
      doc.setTextColor(...darkColor);
      doc.setFontSize(9);
      doc.setFont("helvetica", "italic");
      doc.text(`Amount in words: ${amountInWords}`, margin, wordsY);

      yPos = wordsY + 10;

      // Payment status box (if partially paid)
      if (Number(invoice.paid_amount) > 0) {
        doc.setFillColor(220, 252, 231); // Green tint
        doc.roundedRect(margin, yPos, pageWidth - margin * 2, 22, 3, 3, "F");
        
        doc.setTextColor(22, 163, 74);
        doc.setFontSize(10);
        doc.setFont("helvetica", "bold");
        doc.text("PAYMENT RECEIVED", margin + 10, yPos + 10);
        doc.text(`₹${Number(invoice.paid_amount).toFixed(2)}`, margin + 80, yPos + 10);
        
        const balance = Number(invoice.final_amount) - Number(invoice.paid_amount);
        if (balance > 0) {
          doc.setTextColor(220, 38, 38);
          doc.text(`Balance Due: ₹${balance.toFixed(2)}`, pageWidth - margin - 10, yPos + 10, { align: "right" });
        }
        
        yPos += 28;
      }

      // Footer section
      const footerY = pageHeight - 35;
      
      // Decorative footer line
      doc.setFillColor(...secondaryColor);
      doc.rect(0, footerY - 8, pageWidth, 3, "F");

      // Thank you message
      doc.setTextColor(...primaryColor);
      doc.setFontSize(14);
      doc.setFont("helvetica", "bold");
      doc.text("Thank you for choosing Awadh Dairy!", pageWidth / 2, footerY + 2, { align: "center" });

      // Footer info
      doc.setTextColor(...darkColor);
      doc.setFontSize(8);
      doc.setFont("helvetica", "normal");
      doc.text(
        "For queries: contact@awadhdairy.com | Payment due within 15 days | Fresh Quality Guaranteed",
        pageWidth / 2,
        footerY + 10,
        { align: "center" }
      );

      // Generated timestamp
      doc.setFontSize(7);
      doc.setTextColor(150, 150, 150);
      doc.text(
        `Generated on ${format(new Date(), "dd MMM yyyy 'at' HH:mm")} | www.awadhdairy.com`,
        pageWidth / 2,
        footerY + 17,
        { align: "center" }
      );

      if (action === "download") {
        doc.save(`Invoice_${invoice.invoice_number}_${customer.name.replace(/\s+/g, "_")}.pdf`);
        onGenerated?.();
      } else {
        const dataUrl = doc.output("datauristring");
        setPdfDataUrl(dataUrl);
        setPreviewOpen(true);
      }
    } catch (error) {
      logger.error("InvoicePDF", "Error generating PDF", error);
    } finally {
      setGenerating(false);
    }
  };

  return (
    <>
      <div className="flex items-center gap-1">
        <Button
          variant="outline"
          size="sm"
          className="gap-1"
          onClick={() => generatePDF("preview")}
          disabled={generating}
        >
          <Eye className="h-3 w-3" />
        </Button>
        <Button
          variant="default"
          size="sm"
          className="gap-1"
          onClick={() => generatePDF("download")}
          disabled={generating}
        >
          {generating ? (
            <Loader2 className="h-3 w-3 animate-spin" />
          ) : (
            <Download className="h-3 w-3" />
          )}
          PDF
        </Button>
      </div>

      <Dialog open={previewOpen} onOpenChange={setPreviewOpen}>
        <DialogContent className="max-w-4xl h-[90vh]">
          <DialogHeader>
            <DialogTitle>Invoice Preview - {invoice.invoice_number}</DialogTitle>
          </DialogHeader>
          {pdfDataUrl && (
            <iframe
              src={pdfDataUrl}
              className="w-full h-full rounded-lg border"
              title="Invoice Preview"
            />
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
