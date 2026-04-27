
NUM_VECTORS = 9999          # Total number of testcases to generate

def main() -> None:
    path = "vectors.txt"

    testcases: list[int] = []
    for num in range(0,9999+1):
        testcases.append(num)

    # Write files
    with open(path, "w") as fa:
        for num in testcases:
            fa.write(f"{num} {num}\n")

    print(f"Wrote: {path}")

if __name__ == "__main__":
    main()