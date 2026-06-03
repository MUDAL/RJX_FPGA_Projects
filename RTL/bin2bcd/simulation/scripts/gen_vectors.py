
NUM_VECTORS = pow(2,16)  # Total number of testcases to generate

def main() -> None:
    path = "vectors.txt"

    testcases: list[int] = []
    for num in range(0,NUM_VECTORS):
        testcases.append(num)

    testcases.append(pow(2,32) - 1)

    # Write files
    with open(path, "w") as fa:
        for num in testcases:
            fa.write(f"{num} {num}\n")

    print(f"Wrote: {path}")

if __name__ == "__main__":
    main()