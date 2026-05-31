//  Copyright (c) 2026 Olaoluwa Raji
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

package pkg;   
   // Brief: Determine if a number is a power of 2.
   // Param: Value to be tested.
   // Reference: https://stackoverflow.com/questions/600293/how-to-check-if-a-number-is-a-power-of-2
   function bit is_pwr2(int value);
      return (value & (value - 1)) == 0;
   endfunction

   // Brief: Determine the ceiling of log2 of an integer input.
   // Param: value - Input to the ceil(log2()) operation.
   function int clog2(int value);
      if(!is_pwr2(value)) begin
         clog2 = $clog2(value);
      end
      else begin
         clog2 = $clog2(value) + 1;
      end
      return clog2;
   endfunction
   
   // Brief: Determine the ceiling of a ratio of two integers.
   // Param: num   - Numerator.
   // Param: denom - Denominator.
   function int ceil(int num, int denom);
      ceil = (num + denom - 1) / denom;
   endfunction
   
   // For bin2bcd module
   parameter int BIN_WIDTH  = 14;
   parameter int BCD_DIGITS = pkg::ceil(BIN_WIDTH,3);
   parameter int BCD_WIDTH  = 4*BCD_DIGITS;  
endpackage
