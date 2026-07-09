import argparse

request_conv = {
    "Read"  : "RD",
    "Write" : "WR"
}


def convert(args):
    input_file = open(args.input)
    output_file = open(args.output, "w")

    for input_file_line in input_file.readlines():
        l = input_file_line.split(" ")
        cmd = request_conv[l[2]]
        address = int(l[10], 16)

        output_file.write(f"{cmd} {address:0>32b}\n")



    input_file.close()
    output_file.close()



def main():
    parser = argparse.ArgumentParser(prog="prepare_log_for_verilog.py", description="Format logs from Gem5 to Verilog")
    parser.add_argument("-i", "--input", help="Source file (Gem5 memory access trace)", required=True)
    parser.add_argument("-o" , "--output", help="Destination file (Verilog request trace)", required=True)
    args = parser.parse_args()

    convert(args)


if __name__ == "__main__":
    main()