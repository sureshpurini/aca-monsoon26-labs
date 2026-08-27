// TbMatMul2.bsv --- self-checking testbench for mkMatMul2.
//
// Three vectors, chosen to catch the three things most likely to be wrong in a
// fresh install rather than in the design: arithmetic, elaboration, and signed
// types.  The last line of output is the one that matters.

package TbMatMul2;

import Vector   :: *;
import StmtFSM  :: *;
import MatMul2  :: *;

(* synthesize *)
module mkTbMatMul2 (Empty);

   Reg #(int) rg_errs <- mkReg (0);

   MatMul2_IFC dut <- mkMatMul2;

   // ----------------------------------------------------------------
   // Compare against the hand-computed answer and say so either way.

   function Action check (String name, Mat got, Mat want);
      action
	 Bool ok = True;
	 for (Integer i = 0; i < numN; i = i + 1)
	    for (Integer j = 0; j < numN; j = j + 1)
	       if (got[i][j] != want[i][j]) ok = False;

	 if (ok)
	    $display ("  ok    %s  = [[%0d %0d] [%0d %0d]]",
		      name, got[0][0], got[0][1], got[1][0], got[1][1]);
	 else begin
	    $display ("  FAIL  %s", name);
	    $display ("          got  [[%0d %0d] [%0d %0d]]",
		      got[0][0],  got[0][1],  got[1][0],  got[1][1]);
	    $display ("          want [[%0d %0d] [%0d %0d]]",
		      want[0][0], want[0][1], want[1][0], want[1][1]);
	    rg_errs <= rg_errs + 1;
	 end
      endaction
   endfunction

   // ----------------------------------------------------------------
   // One pair per pass: `put` this cycle, `get` the next.  The FIFO guards do
   // the waiting, so the sequence never mentions timing.

   function Stmt one (String name, Mat a, Mat b, Mat want);
      return (seq
		 dut.put (a, b);
		 action
		    let c <- dut.get;
		    check (name, c, want);
		 endaction
	      endseq);
   endfunction

   Stmt test =
   seq
      $display ("=== Lab 0 smoke test: 2x2 matrix multiply ===");

      // [[1 2] [3 4]] x [[5 6] [7 8]] = [[19 22] [43 50]]
      one ("A x B          ",
	   mkMat (1, 2, 3, 4),
	   mkMat (5, 6, 7, 8),
	   mkMat (19, 22, 43, 50));

      // A x I = A  -- catches a transposed or mis-indexed inner loop.
      one ("A x I          ",
	   mkMat (1, 2, 3, 4),
	   mkMat (1, 0, 0, 1),
	   mkMat (1, 2, 3, 4));

      // Signed operands -- catches Int/UInt confusion, which otherwise hides
      // until the accelerator meets a real RISC-V program.
      one ("signed operands",
	   mkMat (1, -2, -3, 4),
	   mkMat (2,  0,  1, -1),
	   mkMat (0,  2, -2, -4));

      action
	 if (rg_errs == 0)
	    $display ("SMOKE TEST PASSED");
	 else
	    $display ("SMOKE TEST FAILED (%0d of 3 cases wrong)", rg_errs);
      endaction
   endseq;

   mkAutoFSM (test);
endmodule

endpackage: TbMatMul2
