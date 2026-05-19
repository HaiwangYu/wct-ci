import h5py
import sys
import os
import numpy as np
from collections import defaultdict

def format_size(size_bytes):
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024**2:
        return f"{size_bytes/1024:.2f} KB"
    elif size_bytes < 1024**3:
        return f"{size_bytes/1024**2:.2f} MB"
    else:
        return f"{size_bytes/1024**3:.2f} GB"

def analyze_dataset(name, node, stats):
    if isinstance(node, h5py.Dataset):
        # Get storage size
        storage_size = node.id.get_storage_size()
        logical_size = node.nbytes
        
        compression = node.compression
        compression_opts = node.compression_opts
        shuffle = node.shuffle
        chunks = node.chunks
        num_attrs = len(node.attrs)
        
        # Shape and Type
        shape_str = str(node.shape)
        dtype_name = node.dtype.name
        
        stats['total_logical_bytes'] += logical_size
        stats['total_storage_bytes'] += storage_size
        stats['dataset_count'] += 1
        stats['total_attrs'] += num_attrs
        
        # Group by name (leaf name) to identify similar structures
        leaf_name = name.split('/')[-1]
        
        stats['by_name'][leaf_name].append({
            'path': name,
            'shape_str': shape_str,
            'dtype_name': dtype_name,
            'logical': logical_size,
            'storage': storage_size,
            'compression': compression,
            'opts': compression_opts,
            'chunks': chunks,
            'shuffle': shuffle,
            'attrs': num_attrs
        })

def main():
    if len(sys.argv) < 2:
        print("Usage: python inspect_h5.py <h5_file>")
        sys.exit(1)
        
    filename = sys.argv[1]
    
    if not os.path.exists(filename):
        print(f"Error: File '{filename}' not found.")
        sys.exit(1)

    file_size = os.path.getsize(filename)

    stats = {
        'total_logical_bytes': 0,
        'total_storage_bytes': 0,
        'dataset_count': 0,
        'total_attrs': 0,
        'by_name': defaultdict(list)
    }
    
    print(f"Inspecting: {filename}")
    
    try:
        with h5py.File(filename, 'r') as f:
            f.visititems(lambda name, node: analyze_dataset(name, node, stats))
            
        print("\n=== File Summary ===")
        print(f"Total OS File Size:    {format_size(file_size)}")
        print(f"Total Datasets:        {stats['dataset_count']}")
        print(f"Total Logical Size:    {format_size(stats['total_logical_bytes'])}")
        print(f"Total Data on Disk:    {format_size(stats['total_storage_bytes'])}")
        
        overhead = file_size - stats['total_storage_bytes']
        print(f"File Metadata/Overhead: {format_size(overhead)} ({overhead/file_size*100:.1f}%)")

        if stats['total_storage_bytes'] > 0:
            total_ratio = stats['total_logical_bytes'] / stats['total_storage_bytes']
            print(f"Overall Compression:   {total_ratio:.2f}x")
        else:
             print("Overall Compression:   N/A")

        print("\n=== Analysis by Dataset Name (Grouped) ===")
        header = f"{'Name':<22} | {'Cnt':<3} | {'Type':<8} | {'Shape':<15} | {'Logical':<9} | {'Storage':<9} | {'Ratio':<5} | {'Comp':<5}"
        print(header)
        print("-" * len(header))
        
        # Sort by total storage size
        sorted_groups = []
        for name, items in stats['by_name'].items():
            total_logical = sum(i['logical'] for i in items)
            total_storage = sum(i['storage'] for i in items)
            total_attrs = sum(i['attrs'] for i in items)
            ratio = total_logical / total_storage if total_storage > 0 else 1.0
            
            comp_methods = set(str(i['compression']) for i in items)
            comp_str = list(comp_methods)[0] if len(comp_methods) == 1 else "Mixed"
            
            dtypes = set(i['dtype_name'] for i in items)
            dtype_str = list(dtypes)[0] if len(dtypes) == 1 else "Mixed"
            
            shapes = set(i['shape_str'] for i in items)
            shape_str = list(shapes)[0] if len(shapes) == 1 else "Mixed"
            
            sorted_groups.append({
                'name': name,
                'count': len(items),
                'type': dtype_str,
                'shape': shape_str,
                'logical': total_logical,
                'storage': total_storage,
                'ratio': ratio,
                'attrs': total_attrs,
                'comp': comp_str
            })
            
        sorted_groups.sort(key=lambda x: x['storage'], reverse=True)
        
        for g in sorted_groups:
            print(f"{g['name'][:22]:<22} | {g['count']:<3} | {g['type']:<8} | {g['shape'][:15]:<15} | {format_size(g['logical']):<9} | {format_size(g['storage']):<9} | {g['ratio']:<5.1f} | {g['comp'][:5]:<5}")

        # Print Sum row
        total_ratio = stats['total_logical_bytes'] / stats['total_storage_bytes'] if stats['total_storage_bytes'] > 0 else 1.0
        print("-" * len(header))
        print(f"{'TOTAL':<22} | {stats['dataset_count']:<3} | {'-':<8} | {'-':<15} | {format_size(stats['total_logical_bytes']):<9} | {format_size(stats['total_storage_bytes']):<9} | {total_ratio:<5.1f} | {'-':<5}")




        print("\n=== Compression Analysis ===")
        
        poor_compression = [g for g in sorted_groups if g['ratio'] < 1.05 and g['storage'] > 1024]
        if poor_compression:
            print("Poorly compressed (Ratio < 1.05):")
            for g in poor_compression:
                print(f"  - {g['name']}: {g['ratio']:.2f}x ({format_size(g['storage'])})")
        else:
            print("No significant poorly compressed datasets found.")
            
        good_compression = [g for g in sorted_groups if g['ratio'] > 5.0]
        if good_compression:
            print("\nHighly compressed (Ratio > 5.0):")
            for g in good_compression[:5]: # Top 5
                 print(f"  - {g['name']}: {g['ratio']:.2f}x ({format_size(g['storage'])})")
            if len(good_compression) > 5:
                print(f"  ... and {len(good_compression) - 5} more.")

    except OSError as e:
        print(f"Error opening file: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()