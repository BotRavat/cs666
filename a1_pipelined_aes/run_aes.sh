# #!/bin/bash
# # ==================================================
# # AES-128 RTL Simulation & Synthesis Automation
# # ==================================================

# SRC_DIR="./src"
# REPORT_DIR="$SRC_DIR/reports"
# SIM_OUT="aes_sim"

# # Create reports directory if missing
# mkdir -p "$REPORT_DIR"

# # Set Pipelined Metrics for Reporting (Theoretical)
# TARGET_FMAX_MHZ=200      # Target Frequency for a pipelined design
# DATA_BITS=128            # AES-128 data width
# CYCLES_PER_BLOCK=1       # Fully pipelined throughput

# SUMMARY_FILE="$REPORT_DIR/aes_summary.txt"
# REPORT_FILE="$REPORT_DIR/AESEncrypt128_DUT_report.txt"
# YOSYS_SYNTH_SCRIPT="synth_netlist.ys"

# # -------------------------------
# # Step 1: Compile & simulate RTL
# # -------------------------------
# echo "=== Step 1: Compiling and simulating AES-128 RTL ==="
# iverilog -o "$SIM_OUT" \
#     "$SRC_DIR"/test_AES128.v \
#     "$SRC_DIR"/AESEncrypt.v \
#     "$SRC_DIR"/AddRoundKey.v \
#     "$SRC_DIR"/KeyExpansion.v \
#     "$SRC_DIR"/MixColumns.v \
#     "$SRC_DIR"/ShiftRows.v \
#     "$SRC_DIR"/SubBytes.v \
#     "$SRC_DIR"/SubTable.v

# echo "Running simulation..."
# vvp "$SIM_OUT"

# echo "Simulation complete. Above shows encryption result."




#!/bin/bash
# ==================================================
# AES-128 RTL Simulation & Synthesis Automation
# Stops simulation if DUT produces X's
# ==================================================

SRC_DIR="./src"
REPORT_DIR="$SRC_DIR/reports"
SIM_OUT="aes_sim"

# Create reports directory if missing
mkdir -p "$REPORT_DIR"

# Step 1: Compile RTL using Icarus Verilog
echo "=== Step 1: Compiling AES-128 RTL ==="
iverilog -Wall -g2012 -o "$SIM_OUT" \
    "$SRC_DIR"/test_AES128.v \
    "$SRC_DIR"/AESEncrypt.v \
    "$SRC_DIR"/AddRoundKey.v \
    "$SRC_DIR"/KeyExpansion.v \
    "$SRC_DIR"/MixColumns.v \
    "$SRC_DIR"/ShiftRows.v \
    "$SRC_DIR"/SubBytes.v \
    "$SRC_DIR"/SubTable.v

if [ $? -ne 0 ]; then
    echo "Compilation failed! Check RTL syntax."
    exit 1
fi

# Step 2: Run simulation
echo "=== Step 2: Running simulation ==="
vvp "$SIM_OUT" | tee "$REPORT_DIR/aes_sim_log.txt"

# Step 3: Check simulation log for X's
if grep -q "produced X's" "$REPORT_DIR/aes_sim_log.txt"; then
    echo "❌ Simulation produced X's. RTL bug detected!"
    exit 1
else
    echo "✅ Simulation completed without X's."
fi

echo "Simulation log saved to $REPORT_DIR/aes_sim_log.txt"


# read -p "Press ENTER to continue to synthesis, or Ctrl+C to abort..."

# # -------------------------------
# # Step 2: Synthesis with Yosys
# # -------------------------------
# echo "=== Step 2a: Generating Netlist using Yosys ==="

# # Create script to load files and synthesize
# cat > "$YOSYS_SYNTH_SCRIPT" <<EOL
# # Read only RTL modules, exclude testbench
# read_verilog $SRC_DIR/SubTable.v
# read_verilog $SRC_DIR/SubBytes.v
# read_verilog $SRC_DIR/ShiftRows.v
# read_verilog $SRC_DIR/MixColumns.v
# read_verilog $SRC_DIR/AddRoundKey.v
# read_verilog $SRC_DIR/KeyExpansion.v
# read_verilog $SRC_DIR/AESEncrypt.v

# # Top module
# synth -top AESEncrypt128_DUT

# # Write netlist 
# write_verilog $REPORT_DIR/AESEncrypt128_DUT_netlist.v
# EOL

# # Run Yosys for netlist generation
# if ! yosys -s "$YOSYS_SYNTH_SCRIPT"; then
#     echo "Error: Yosys netlist synthesis failed! Check Verilog RTL syntax."
#     exit 1
# fi

# echo "Netlist generated successfully: $REPORT_DIR/AESEncrypt128_DUT_netlist.v"

# # -------------------------------
# # Step 2b: Statistics Generation (Isolated)
# # -------------------------------
# echo "=== Step 2b: Generating Synthesis Report (Statistics) ==="

# # Run Yosys again for the 'stat' command, piping output to the report file.
# if ! yosys -p "read_verilog $REPORT_DIR/AESEncrypt128_DUT_netlist.v; hierarchy -top AESEncrypt128_DUT; stat" > "$REPORT_FILE"; then
#     echo "Warning: Yosys 'stat' command failed to generate a complete report. Proceeding with summary generation."
# fi

# echo "Synthesis complete. Netlist and report generated in $REPORT_DIR."

# # -------------------------------
# # Step 3: Generate modular summary and Pipelined Metrics
# # -------------------------------

# # Create the summary file (using quotes for robustness)
# > "$SUMMARY_FILE"
# echo "=== AES-128 Synthesis Summary ===" >> "$SUMMARY_FILE"
# echo "Generated on $(date)" >> "$SUMMARY_FILE"
# echo "" >> "$SUMMARY_FILE"

# if [ ! -f "$REPORT_FILE" ]; then
#     echo "Error: Final Yosys report file not found at $REPORT_FILE. Cannot generate summary." >> "$SUMMARY_FILE"
# else
    
#     FILE="$REPORT_FILE"
#     MODULE_NAME=$(basename "$FILE" | sed 's/_report.txt//')
    
#     # --- Resource Extraction ---
#     # NOTE: These grep/awk patterns rely on the specific Yosys output format.
#     # Wires, WireBits, Cells: Target the last instance of these lines.
#     Wires=$(grep "Number of wires:" "$FILE" | awk '{print $4}' | tail -n 1)
#     WireBits=$(grep "Number of wire bits:" "$FILE" | awk '{print $5}' | tail -n 1)
#     Cells=$(grep "Number of cells:" "$FILE" | awk '{print $4}' | tail -n 1)
    
#     # LUTs: Using $_ANDNOT_ as a proxy, targeting the last instance (from hierarchy total)
#     LUTs=$(grep "\$_ANDNOT_" "$FILE" | awk '{print $2}' | tail -n 1)

#     # Flip-Flops: Sum ALL $_DFFE_ cells in the report
#     FFs=$(grep "\$_DFFE_" "$FILE" | awk '{s+=$2} END {print s}')

#     # BRAMs and DSPs: Target the last instance.
#     BRAMs=$(grep "\$_MEM_" "$FILE" | awk '{print $2}' | tail -n 1)
#     DSPs=$(grep "\$_DSP_" "$FILE" | awk '{print $2}' | tail -n 1)
    
#     BRAMs=${BRAMs:-0}
#     DSPs=${DSPs:-0}
    
#     # Fallback/Sanitization
#     Wires=${Wires:-0}
#     WireBits=${WireBits:-0}
#     Cells=${Cells:-0}
#     LUTs=${LUTs:-0}
#     FFs=${FFs:-0}

#     # --- Calculation of Pipelined Metrics ---
#     # Theoretical Throughput Calculation (in Gbps)
#     # Formula: (Target Fmax (MHz) * Data Bits) / (Cycles per Block * 1000) = Gbps
#     Throughput_Gbps=$(echo "scale=2; ${TARGET_FMAX_MHZ} * ${DATA_BITS} / (${CYCLES_PER_BLOCK} * 1000)" | bc)

#     echo "Module: $MODULE_NAME (Fully Pipelined)" >> "$SUMMARY_FILE"
#     echo "---------------------------------" >> "$SUMMARY_FILE"
#     printf "| %-18s | %-12s |\n" "Parameter" "Value" >> "$SUMMARY_FILE"
#     echo "---------------------------------" >> "$SUMMARY_FILE"
#     printf "| %-18s | %-12s |\n" "Total LUTs (Area)" "$LUTs" >> "$SUMMARY_FILE"
#     printf "| %-18s | %-12s |\n" "Total Flip-Flops" "$FFs" >> "$SUMMARY_FILE"
#     printf "| %-18s | %-12s |\n" "BRAMs / DSPs" "$BRAMs / $DSPs" >> "$SUMMARY_FILE"
#     echo "---------------------------------" >> "$SUMMARY_FILE"
    
#     # Pipelined Metrics
#     echo "| **Pipelined Performance** | **(Theoretical)** |" >> "$SUMMARY_FILE"
#     printf "| %-18s | %-12s |\n" "Target Fmax" "${TARGET_FMAX_MHZ} MHz" >> "$SUMMARY_FILE"
#     printf "| %-18s | %-12s |\n" "Cycles per Block" "$CYCLES_PER_BLOCK" >> "$SUMMARY_FILE"
#     printf "| %-18s | %-12s |\n" "Throughput" "${Throughput_Gbps} Gbps" >> "$SUMMARY_FILE"
#     echo "---------------------------------" >> "$SUMMARY_FILE"
#     echo "" >> "$SUMMARY_FILE"
# fi

# echo "Done! Check $SUMMARY_FILE for synthesis summary."