import sys
import argparse

def trace(args):
    input_file = open(args.input)
    if args.output is not None:
        output_file = open(args.output, "w")
    for input_file_line in input_file.readlines():
        l = input_file_line.split(" ")
        cmd = l[2]

        if cmd == "Read":
            cmd_sequence = ["PRE", "ACT", "RD"]
        elif cmd == "Write":
            cmd_sequence = ["PRE", "ACT", "WRT"]
        else:
            print("Request error")
            exit(1)

        for c in cmd_sequence:
            if args.output is not None:
                output_file.write(c+'\n')
            else:
                print(c)
            
    input_file.close()
    if args.output is not None:
        output_file.close()

def main():
    parser = argparse.ArgumentParser(prog="mem_requests_trace_to_hbm_cmd.py", description="Memory requests trace into HBM memory commands converter")
    parser.add_argument("-i", "--input", help="Source file (memory requests trace)", required=True)
    parser.add_argument("-o" , "--output", help="Destination file (HBM commands trace)")
    args = parser.parse_args()

    trace(args)


if __name__ == "__main__":
    main()