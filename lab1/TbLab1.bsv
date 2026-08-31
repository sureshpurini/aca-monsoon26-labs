// TbLab1.bsv --- the Lab 1 testbench.  DO NOT EDIT for submission.
//
// This is the same testbench we grade with.  It drives your `mkMatMul` through
// both workloads, checks every value it returns against an independent
// behavioural model, and reports cycles.
//
//   W1  "deep"      1 epoch  x 64 Muls,  16 reads       592 requests
//   W2  "shallow"  32 epochs x  2 Muls, 512 reads      1088 requests
//
// Both do exactly the same arithmetic -- 64 tiles, 4096 multiply-accumulates.
// They differ only in how often C is read out.  See §5 of the README.
//
// One request is issued per cycle whenever your unit will accept one, so the
// cycle counts are your unit's behaviour and not the testbench's.  `stalls` is
// cycles minus requests: the number of cycles your unit spent not accepting
// work.  For a design that answers everything in one cycle it is 1 (the last
// response lands the cycle after the last request).  If it is large, §8 of the
// README is where to start.
//
// You are welcome to READ this file -- it is the precise statement of what
// "correct" means, and it is more specific than prose can be.

package TbLab1;

import Vector   :: *;
import FIFOF    :: *;
import MM_Types :: *;
import MatMul   :: *;

// ================================================================
// Test data, generated from the tile index so no literals are needed.
// Elements land in [-8, 7], so 64 accumulated tiles stay far inside Int32.

function Elem gen_elem (Bit #(16) t, Bit #(8) i, Bit #(8) j, Bit #(8) salt);
   Bit #(16) h = (t * 2654) + (zeroExtend (i) * 37) + (zeroExtend (j) * 11)
                 + zeroExtend (salt);
   Bit #(4) v = truncate (h >> 2);
   return unpack (signExtend (v));
endfunction

function Bit #(32) a_row_word (Bit #(16) t, Bit #(8) i);
   Vector #(K_DIM, Elem) r = newVector;
   for (Integer l = 0; l < k_dim; l = l + 1)
      r[l] = gen_elem (t, i, fromInteger (l), 0);
   return pack (reverse (r));
endfunction

function Bit #(32) b_row_word (Bit #(16) t, Bit #(8) l);
   Vector #(N_DIM, Elem) r = newVector;
   for (Integer j = 0; j < n_dim; j = j + 1)
      r[j] = gen_elem (t, l, fromInteger (j), 99);
   return pack (reverse (r));
endfunction

function A_Mat gen_a (Bit #(16) t);
   A_Mat a = newVector;
   for (Integer i = 0; i < m_dim; i = i + 1)
      for (Integer l = 0; l < k_dim; l = l + 1)
	 a[i][l] = gen_elem (t, fromInteger (i), fromInteger (l), 0);
   return a;
endfunction

function B_Mat gen_b (Bit #(16) t);
   B_Mat b = newVector;
   for (Integer l = 0; l < k_dim; l = l + 1)
      for (Integer j = 0; j < n_dim; j = j + 1)
	 b[l][j] = gen_elem (t, fromInteger (l), fromInteger (j), 99);
   return b;
endfunction

// The behavioural reference: C += A*B, one tile at a time, strictly in order.
// This function IS the correctness condition of §4 -- your unit may overlap
// whatever it likes, as long as it returns what this would have returned.
function C_Mat ref_mac (A_Mat a, B_Mat b, C_Mat c);
   C_Mat o = c;
   for (Integer i = 0; i < m_dim; i = i + 1)
      for (Integer j = 0; j < n_dim; j = j + 1) begin
	 Acc s = c[i][j];
	 for (Integer l = 0; l < k_dim; l = l + 1)
	    s = s + (signExtend (a[i][l]) * signExtend (b[l][j]));
	 o[i][j] = s;
      end
   return o;
endfunction

// ================================================================

interface Run_IFC;
   method Bool       done;
   method Bit #(32)  cycles;
   method Bit #(32)  errs;
   method Bit #(32)  reqs;
endinterface

typedef enum {P_LOADA, P_LOADB, P_MUL, P_READ, P_DONE} Phase deriving (Bits, Eq);

module mkRun #(Integer epochs, Integer tiles_per_epoch) (Run_IFC);

   MatMul_IFC dut <- mkMatMul;

   Reg #(Phase)      rg_ph    <- mkReg (P_LOADA);
   Reg #(Bit #(8))   rg_idx   <- mkReg (0);      // row within a load burst
   Reg #(Bit #(8))   rg_rrow  <- mkReg (0);      // read row
   Reg #(Bit #(8))   rg_rchk  <- mkReg (0);      // read chunk
   Reg #(Bit #(8))   rg_tile  <- mkReg (0);      // tile within epoch
   Reg #(Bit #(16))  rg_gtile <- mkReg (0);      // global tile, seeds the data
   Reg #(Bit #(16))  rg_epoch <- mkReg (0);

   Reg #(C_Mat)      rg_ref   <- mkReg (replicate (replicate (0)));
   Reg #(Bit #(32))  rg_cycle <- mkReg (0);
   Reg #(Bit #(32))  rg_end   <- mkReg (0);
   Reg #(Bit #(32))  rg_reqs  <- mkReg (0);
   Reg #(Bit #(32))  rg_errs  <- mkReg (0);
   Reg #(Bit #(32))  rg_got   <- mkReg (0);

   Reg #(Bit #(32))  rg_cmp   <- mkReg (0);

   // Expected values, computed when a read is *issued* -- the shadow C moves on
   // afterwards, so comparing at response time against the live shadow would be
   // wrong.
   FIFOF #(Bit #(32)) f_expect <- mkSizedFIFOF (1024);

   // Values actually returned.  Draining and comparing are deliberately two
   // rules: if one rule did both, bsc would hoist `f_expect.first`'s implicit
   // condition into the rule's guard, and the rule could not drain the
   // valueless responses to LoadA/LoadB/Mul until a read had been issued.  In
   // W1 that is 576 requests -- your response FIFO fills, `req` blocks, and the
   // whole thing deadlocks.  Splitting the rules is the fix.
   FIFOF #(Bit #(32)) f_got <- mkSizedFIFOF (1024);

   Integer c_words   = words_per_c_row;
   Integer total_rds = m_dim * c_words;

   rule rl_cycle;
      rg_cycle <= rg_cycle + 1;
   endrule

   rule rl_drive (rg_ph != P_DONE);
      rg_reqs <= rg_reqs + 1;

      case (rg_ph)
	 P_LOADA: begin
		     dut.req (tagged LoadA MM_Wr {row:   rg_idx,
						  chunk: 0,
						  word:  a_row_word (rg_gtile, rg_idx)});
		     if (rg_idx == fromInteger (m_dim - 1)) begin
			rg_ph  <= P_LOADB;
			rg_idx <= 0;
		     end
		     else rg_idx <= rg_idx + 1;
		  end

	 P_LOADB: begin
		     dut.req (tagged LoadB MM_Wr {row:   rg_idx,
						  chunk: 0,
						  word:  b_row_word (rg_gtile, rg_idx)});
		     if (rg_idx == fromInteger (k_dim - 1)) rg_ph <= P_MUL;
		     else rg_idx <= rg_idx + 1;
		  end

	 P_MUL:   begin
		     dut.req (tagged Mul);
		     rg_ref   <= ref_mac (gen_a (rg_gtile), gen_b (rg_gtile), rg_ref);
		     rg_gtile <= rg_gtile + 1;

		     if (rg_tile == fromInteger (tiles_per_epoch - 1)) begin
			rg_ph   <= P_READ;
			rg_tile <= 0;
			rg_rrow <= 0;
			rg_rchk <= 0;
		     end
		     else begin
			rg_tile <= rg_tile + 1;
			rg_ph   <= P_LOADA;
			rg_idx  <= 0;
		     end
		  end

	 P_READ:  begin
		     dut.req (tagged ReadC MM_Rd {row: rg_rrow, chunk: rg_rchk});

		     // Expected value, and the destructive zeroing the README
		     // requires the unit to perform.
		     let c = rg_ref;
		     f_expect.enq (pack (c [rg_rrow][rg_rchk]));
		     c [rg_rrow][rg_rchk] = 0;
		     rg_ref <= c;

		     if (rg_rchk == fromInteger (c_words - 1)) begin
			rg_rchk <= 0;
			if (rg_rrow == fromInteger (m_dim - 1)) begin
			   // Epoch finished.
			   if (rg_epoch == fromInteger (epochs - 1))
			      rg_ph <= P_DONE;
			   else begin
			      rg_epoch <= rg_epoch + 1;
			      rg_ph    <= P_LOADA;
			      rg_idx   <= 0;
			   end
			end
			else rg_rrow <= rg_rrow + 1;
		     end
		     else rg_rchk <= rg_rchk + 1;
		  end

	 P_DONE:  noAction;
      endcase
   endrule

   // Drain every response.  Only the ones carrying a value are kept; the rest
   // are discarded, having done their job of keeping the two streams in step.
   rule rl_drain;
      let r <- dut.rsp;
      if (r.has_value) begin
	 f_got.enq (r.value);
	 rg_got <= rg_got + 1;
	 if (rg_got == fromInteger ((epochs * total_rds) - 1))
	    rg_end <= rg_cycle;      // cycle of the LAST value response
      end
   endrule

   rule rl_compare;
      let got  = f_got.first;    f_got.deq;
      let want = f_expect.first; f_expect.deq;
      if (got != want) begin
	 if (rg_errs < 5)
	    $display ("      mismatch at read %0d: got %0d, expected %0d",
		      rg_cmp, unpack (got), unpack (want));
	 rg_errs <= rg_errs + 1;
      end
      rg_cmp <= rg_cmp + 1;
   endrule

   method Bool      done   = (rg_cmp == fromInteger (epochs * total_rds));
   method Bit #(32) cycles = rg_end;
   method Bit #(32) errs   = rg_errs;
   method Bit #(32) reqs   = rg_reqs;
endmodule

// ================================================================

(* synthesize *)
module mkTbLab1 (Empty);

   // W1: one deep epoch.  W2: many shallow ones.  Same arithmetic.
   Run_IFC w1 <- mkRun (1,  64);
   Run_IFC w2 <- mkRun (32,  2);

   Reg #(Bool) rg_done <- mkReg (False);

   function Action row (String name, Run_IFC r);
      action
	 $display ("  %s %9d %8d %8d %8d", name,
		   r.reqs, r.cycles, r.cycles - r.reqs, r.errs);
      endaction
   endfunction

   rule rl_report (! rg_done && w1.done && w2.done);
      rg_done <= True;
      $display ("================================================================");
      $display ("Lab 1 --- %0dx%0dx%0d, Int%0d operands, Int%0d accumulator",
		m_dim, k_dim, n_dim, w_elem, w_acc);
      $display ("================================================================");
      $display ("");
      $display ("  workload    requests   cycles   stalls   errors");
      $display ("  ----------  --------  -------  -------  -------");
      row ("W1 deep   ", w1);
      row ("W2 shallow", w2);
      $display ("");

      if ((w1.errs | w2.errs) == 0)
	 $display ("LAB1 OK  (correct on both workloads)");
      else
	 $display ("LAB1 FAILED  (%0d + %0d mismatches)", w1.errs, w2.errs);
      $finish (0);
   endrule
endmodule

endpackage: TbLab1
