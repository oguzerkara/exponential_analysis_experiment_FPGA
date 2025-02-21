import pandas as pd
import struct

# Function to convert a float to IEEE 754 single-precision format (4 bytes)
def float_to_ieee754(value):
    return struct.pack('>f', float(value)).hex().upper()

# Load the CSV file
file_path = './NVDA_close_values.csv'
data = pd.read_csv(file_path)

# Convert 'Date' column to string format and remove time information
data['Date'] = pd.to_datetime(data['Date']).dt.strftime('%Y-%m-%d')

# Drop any rows with NaN values
data = data.dropna()

# Output MIF file path
output_mif = './NVDA_daily_stock.mif'

# Open the output file
with open(output_mif, 'w') as outfile:
    # Memory parameters
    depth = len(data)  # Number of records
    width = 64  # Total width (Date: 4 bytes, Value: 4 bytes)

    # Write MIF file headers
    outfile.write(f"WIDTH={width};\n")
    outfile.write(f"DEPTH={depth};\n")
    outfile.write("ADDRESS_RADIX=UNS;\n")
    outfile.write("DATA_RADIX=HEX;\n")
    outfile.write("CONTENT BEGIN\n")

    # Process each row in the DataFrame
    for addr, row in data.iterrows():
        date, value = row['Date'], row['Close']
        year, month, day = map(int, date.split('-'))

        # Convert components to hexadecimal
        year_hex = f"{year:04X}"      # Year as 2 bytes (16-bit)
        month_hex = f"{month:02X}"   # Month as 1 byte (8-bit)
        day_hex = f"{day:02X}"       # Day as 1 byte (8-bit)
        value_hex = float_to_ieee754(value)  # Float as 4 bytes (32-bit)

        # Combine all components (8 bytes total: 2 bytes for year, 1 byte for month, 1 byte for day, 4 bytes for value)
        record = f"{year_hex}{month_hex}{day_hex}{value_hex}"
        
        # Write to MIF file
        outfile.write(f"    {addr} : {record};\n")

    # Finalize MIF file
    outfile.write("END;\n")

print(f"MIF file saved: {output_mif}")
