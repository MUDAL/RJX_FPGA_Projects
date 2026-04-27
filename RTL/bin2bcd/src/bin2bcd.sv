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

// Binary-to-BCD top module.

// Algorithm reference: https://en.wikipedia.org/wiki/Double_dabble

module bin2bcd #(parameter int          VERSION = 2)(
                 input     logic        clk,
                 input     logic        rst_n,
                 input     logic        valid_in,
                 input     logic [13:0] bin,
                 output    logic [15:0] bcd,
                 output    logic        valid_out);
                 
   // Instantiate either version 1 (higher latency) or
   // version 2 (lower latency, FSM-based).
   generate
      if(VERSION == 1) begin
         bin2bcd_v1 bin2bcd_rtl(.clk       (clk),
                                .rst_n     (rst_n),
                                .valid_in  (valid_in),
                                .bin       (bin),
                                .bcd       (bcd),
                                .valid_out (valid_out));
      end
      else begin
         bin2bcd_v2 bin2bcd_rtl(.clk       (clk),
                                .rst_n     (rst_n),
                                .valid_in  (valid_in),
                                .bin       (bin),
                                .bcd       (bcd),
                                .valid_out (valid_out));    
      end
   endgenerate
endmodule
