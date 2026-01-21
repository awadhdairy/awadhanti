/**
 * Convert a number to Indian Rupee words format
 * e.g., 12345.67 -> "Twelve Thousand Three Hundred Forty Five Rupees and Sixty Seven Paise Only"
 */

const ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen'
];

const tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
];

function convertTwoDigits(num: number): string {
  if (num < 20) return ones[num];
  const ten = Math.floor(num / 10);
  const one = num % 10;
  return tens[ten] + (one ? ' ' + ones[one] : '');
}

function convertThreeDigits(num: number): string {
  const hundred = Math.floor(num / 100);
  const remainder = num % 100;
  if (hundred === 0) return convertTwoDigits(remainder);
  if (remainder === 0) return ones[hundred] + ' Hundred';
  return ones[hundred] + ' Hundred ' + convertTwoDigits(remainder);
}

export function numberToIndianWords(amount: number): string {
  if (amount === 0) return 'Zero Rupees Only';
  
  // Handle negative numbers
  if (amount < 0) {
    return 'Minus ' + numberToIndianWords(Math.abs(amount));
  }

  // Split into rupees and paise
  const rupees = Math.floor(amount);
  const paise = Math.round((amount - rupees) * 100);
  
  let words = '';
  
  if (rupees > 0) {
    words = convertRupeesToWords(rupees) + ' Rupees';
  }
  
  if (paise > 0) {
    if (words) words += ' and ';
    words += convertTwoDigits(paise) + ' Paise';
  }
  
  return (words || 'Zero Rupees') + ' Only';
}

function convertRupeesToWords(num: number): string {
  if (num === 0) return '';
  if (num > 9999999999) return 'Amount too large';
  
  // Indian numbering: Crore (10^7), Lakh (10^5), Thousand (10^3), Hundred (10^2)
  const crore = Math.floor(num / 10000000);
  const lakh = Math.floor((num % 10000000) / 100000);
  const thousand = Math.floor((num % 100000) / 1000);
  const remainder = num % 1000;
  
  let words = '';
  
  if (crore > 0) {
    words += convertTwoDigits(crore) + ' Crore ';
  }
  
  if (lakh > 0) {
    words += convertTwoDigits(lakh) + ' Lakh ';
  }
  
  if (thousand > 0) {
    words += convertTwoDigits(thousand) + ' Thousand ';
  }
  
  if (remainder > 0) {
    words += convertThreeDigits(remainder);
  }
  
  return words.trim();
}

/**
 * Shortened format for smaller amounts
 * e.g., 1250.50 -> "One Thousand Two Hundred Fifty Rupees Fifty Paise"
 */
export function amountToWords(amount: number): string {
  return numberToIndianWords(amount);
}
