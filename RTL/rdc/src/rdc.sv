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

// Reset Domain Crossing Module.

// Port signals:
// 1. clock             (clk)
// 2. active-low reset  (rst_n_in)
// 3. active-low reset output with synchronous de-assert (rst_n_out)

module rdc(input  logic clk,
           input  logic rst_n_in,
           output logic rst_n_out);

   logic reg_1;
   logic reg_2;
   
   assign rst_n_out = reg_2;
   
   always_ff @(negedge rst_n_in, posedge clk) begin: registers
      if(!rst_n_in) begin
         reg_1 <= 1'b0;
         reg_2 <= 1'b0;
      end
      else begin
         reg_1 <= 1'b1;
         reg_2 <= reg_1;
      end
   end
endmodule
