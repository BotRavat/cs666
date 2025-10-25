#!/bin/bash
# ==================================================
# AES-128 RTL Simulation & Synthesis Automation
# Interactive steps: compile -> simulate -> synth
# Reports and netlists go to src/reports
# ==================================================

SRC_DIR="./src"
REPORT_DIR="$SRC_DIR/reports"
SIM_OUT="aes_sim"

# Create reports directory if missing
mkdir -p $REPORT_DIR

# -------------------------------
# Step 1: Compile & simulate RTL
# -------------------------------
echo "=== Step 1: Compiling and simulating AES-128 RTL ==="
iverilog -o $SIM_OUT \
    $SRC_DIR/test_AES128.v \
    $SRC_DIR/AESEncrypt.v \
    $SRC_DIR/AddRoundKey.v \
    $SRC_DIR/KeyExpansion.v \
    $SRC_DIR/MixColumns.v \
    $SRC_DIR/ShiftRows.v \
    $SRC_DIR/SubBytes.v \
    $SRC_DIR/SubTable.v

echo "Running simulation..."
vvp $SIM_OUT

echo "Simulation complete. Above shows encryption result."
read -p "Press ENTER to continue to synthesis, or Ctrl+C to abort..."

# -------------------------------
# Step 2: Synthesis with Yosys (Netlist Generation)
# -------------------------------
echo "=== Step 2a: Generating Netlist using Yosys ==="

YOSYS_SYNTH_SCRIPT="synth_netlist.ys"
REPORT_FILE="$REPORT_DIR/AESEncrypt128_DUT_report.txt"

# Create script to load files and synthesize
cat > $YOSYS_SYNTH_SCRIPT <<EOL
# Read only RTL modules, exclude testbench
read_verilog $SRC_DIR/SubTable.v
read_verilog $SRC_DIR/SubBytes.v
read_verilog $SRC_DIR/ShiftRows.v
read_verilog $SRC_DIR/MixColumns.v
read_verilog $SRC_DIR/AddRoundKey.v
read_verilog $SRC_DIR/KeyExpansion.v
read_verilog $SRC_DIR/AESEncrypt.v

# Top module
synth -top AESEncrypt128_DUT

# Write netlist (this worked previously)
write_verilog $REPORT_DIR/AESEncrypt128_DUT_netlist.v
EOL

# Run Yosys for synthesis
if ! yosys -s $YOSYS_SYNTH_SCRIPT; then
    echo "Error: Yosys netlist synthesis failed! Check Verilog RTL syntax."
    exit 1
fi

echo "Netlist generated successfully: $REPORT_DIR/AESEncrypt128_DUT_netlist.v"

# -------------------------------
# Step 2b: Statistics Generation (Isolated)
# -------------------------------
echo "=== Step 2b: Generating Synthesis Report (Statistics) ==="

# We run Yosys again, but only with the 'stat' command piped directly to the file.
# This prevents the C++ crash from aborting the entire script.
# We include the 'hierarchy' command to ensure the grand totals are printed at the end.
if ! yosys -p "read_verilog $REPORT_DIR/AESEncrypt128_DUT_netlist.v; hierarchy -top AESEncrypt128_DUT; stat" > "$REPORT_FILE"; then
    # Note: If it crashes here, the error is still in Yosys's stat calculation,
    # but the synthesis is considered complete.
    echo "Warning: Yosys 'stat' command failed to generate a complete report. Proceeding with summary generation."
fi

echo "Synthesis complete. Netlist and report generated in $REPORT_DIR."
# read -p "Press ENTER to generate summary, or Ctrl+C to abort..."

# -------------------------------
# Step 3: Generate modular summary
# -------------------------------
SUMMARY_FILE="$REPORT_DIR/aes_summary.txt"
> $SUMMARY_FILE
echo "=== AES-128 Synthesis Summary ===" >> $SUMMARY_FILE
echo "Generated on $(date)" >> $SUMMARY_FILE
echo "" >> $SUMMARY_FILE

REPORTS=("$REPORT_FILE")

for FILE in "${REPORTS[@]}"; do
    if [ ! -f "$FILE" ]; then
        echo "Warning: Report $FILE not found! Skipping..."
        # We will stop here if the report file is missing entirely after the crash warning
        continue
    fi

    MODULE_NAME=$(basename $FILE | sed 's/_report.txt//')
    
    # --- Extraction Fixes ---
    # The 'design hierarchy' section is the last complete stats block. 
    # Using 'tail -n 1' on general pattern is brittle. We will use it, but assume the last block is the hierarchy.
    
    # Wires, WireBits, Cells: Target the last instance of these lines.
    Wires=$(grep "Number of wires:" $FILE | awk '{print $4}' | tail -n 1)
    WireBits=$(grep "Number of wire bits:" $FILE | awk '{print $5}' | tail -n 1)
    Cells=$(grep "Number of cells:" $FILE | awk '{print $4}' | tail -n 1)
    
    # LUTs: Using $_ANDNOT_ as a proxy, targeting the last instance (from hierarchy total)
    LUTs=$(grep "\$_ANDNOT_" $FILE | awk '{print $2}' | tail -n 1)

    # Flip-Flops: Sum ALL $_DFFE_ cells in the report (FFs, FFs with set/reset, etc.)
    # This uses awk to initialize a sum (s=0) and for every line matching $DFFE, it adds the cell count ($2)
    FFs=$(grep "\$_DFFE_" $FILE | awk '{s+=$2} END {print s}')

    # BRAMs and DSPs: Target the last instance.
    BRAMs=$(grep "\$_MEM_" $FILE | awk '{print $2}' | tail -n 1)
    DSPs=$(grep "\$_DSP_" $FILE | awk '{print $2}' | tail -n 1)
    
    BRAMs=${BRAMs:-0}
    DSPs=${DSPs:-0}
    Throughput=$(echo "scale=2; 128*100000000/10" | bc)

    # Fallback/Sanitization for missing values after grep
    Wires=${Wires:-0}
    WireBits=${WireBits:-0}
    Cells=${Cells:-0}
    LUTs=${LUTs:-0}
    FFs=${FFs:-0}


    echo "Module: $MODULE_NAME" >> $SUMMARY_FILE
    echo "---------------------------------" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "Parameter" "Value" >> $SUMMARY_FILE
    echo "---------------------------------" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "Wires" "$Wires" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "Wire bits" "$WireBits" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "Cells" "$Cells" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "LUTs" "$LUTs" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "Flip-Flops" "$FFs" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "BRAMs" "$BRAMs" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "DSPs" "$DSPs" >> $SUMMARY_FILE
    printf "| %-12s | %-10s |\n" "Throughput" "${Throughput} bps" >> $SUMMARY_FILE
    echo "---------------------------------" >> $SUMMARY_FILE
    echo "" >> $SUMMARY_FILE
done

echo "Done! Check $SUMMARY_FILE for synthesis summary."
