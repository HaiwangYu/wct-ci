import h5py
import sys
import os
import time
import shutil


def copy_objects(source_group, dest_group, compression_opts):
    for name, item in source_group.items():
        if isinstance(item, h5py.Dataset):
            # Read data
            data = item[:]

            # Create dataset in destination with new compression
            # Keep original chunks if they exist, or let h5py decide?
            # Usually h5repack uses the original chunking if possible or defaults.
            # We will let h5py auto-chunk or use a reasonable default if the original wasn't chunked.
            chunks = item.chunks
            if chunks is None:
                chunks = True  # Enable auto-chunking for compression

            # Filter out kwargs that are None or incompatible
            kwargs = {
                "data": data,
                "chunks": chunks,
                "compression": "gzip",
                "compression_opts": compression_opts,
            }

            dest_group.create_dataset(name, **kwargs)

            # Copy attributes
            for k, v in item.attrs.items():
                dest_group[name].attrs[k] = v

        elif isinstance(item, h5py.Group):
            new_group = dest_group.create_group(name)
            # Copy attributes
            for k, v in item.attrs.items():
                new_group.attrs[k] = v
            # Recurse
            copy_objects(item, new_group, compression_opts)


def test_full_repack(input_filename, level):
    output_filename = f"temp_repack_gzip{level}_{os.getpid()}.h5"

    start_time = time.time()
    try:
        with (
            h5py.File(input_filename, "r") as f_in,
            h5py.File(output_filename, "w") as f_out,
        ):
            # Copy root attributes
            for k, v in f_in.attrs.items():
                f_out.attrs[k] = v

            copy_objects(f_in, f_out, level)

        duration = time.time() - start_time
        size = os.path.getsize(output_filename)
        return size, duration
    finally:
        if os.path.exists(output_filename):
            os.remove(output_filename)


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_compression.py <h5_file>")
        sys.exit(1)

    filename = sys.argv[1]
    original_size = os.path.getsize(filename)
    
    # Calculate total raw uncompressed size
    total_raw_bytes = 0
    def sum_raw_bytes(name, node):
        nonlocal total_raw_bytes
        if isinstance(node, h5py.Dataset):
            total_raw_bytes += node.nbytes

    with h5py.File(filename, 'r') as f:
        f.visititems(sum_raw_bytes)
        dataset_count = sum(1 for _ in f.visititems(lambda n,o: o if isinstance(o, h5py.Dataset) else None))

    print(f"Analyzing file: {filename}")
    print(f"Original File Size: {original_size / 1024 / 1024:.2f} MB")
    print(f"Total Raw Data Size: {total_raw_bytes / 1024 / 1024:.2f} MB")
    print(f"Datasets: {dataset_count}")
    print("\nRunning full file repack tests (this may take a moment)...")
    print("-" * 65)
    print(f"{'Method':<15} | {'Size (MB)':<12} | {'Ratio':<8} | {'Time (s)':<10}")
    print("-" * 65)

    # Test GZIP levels
    levels = [2, 4, 6, 9]
    results = []

    for level in levels:
        print(f"Testing GZIP({level})...", end='\r')
        try:
            size, duration = test_full_repack(filename, level)
            ratio = total_raw_bytes / size
            results.append((f"GZIP({level})", size, ratio, duration))
        except Exception as e:
            print(f"\nError testing GZIP({level}): {e}")

    # Clear progress line
    print(" " * 40, end='\r')

    # Sort by size (ascending)
    results.sort(key=lambda x: x[1])

    for label, size, ratio, duration in results:
        print(f"{label:<15} | {size / 1024 / 1024:<12.2f} | {ratio:<8.2f} | {duration:<10.2f}")
    print("-" * 65)


if __name__ == "__main__":
    main()