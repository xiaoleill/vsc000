import re

with open('d:/mywork/vsc000/ERMU_UT/test/ermu_stress_test.sv', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
for line in lines:
    # Replace $urandom_range(a, b) with safe equivalent
    def repl(m):
        lo = int(m.group(1))
        hi_str = m.group(2).replace('_', '')
        if hi_str.startswith('0x') or hi_str.startswith('0X'):
            hi = int(hi_str, 16)
        elif "'h" in hi_str:
            hi = int(hi_str.split("'h")[1], 16)
        else:
            hi = int(hi_str)
        rng = hi - lo + 1
        if rng > 0:
            return f"((($urandom) & 32'h7FFFFFFF) % {rng}) + {lo}"
        else:
            return f"($urandom) & 32'hFFFFFFFF"
    line = re.sub(r'\$urandom_range\((\d+),\s*([^)]+)\)', repl, line)

    # Remove in-body int/bit declarations that are now pre-declared
    line = line.replace('int z  = ', 'zr = ')
    line = re.sub(r'\bint ch\b\s*=\s*', 'ch = ', line)
    line = re.sub(r'\bint si\b\s*=\s*', 'si = ', line)
    line = re.sub(r'\bint om\b\s*=\s*', 'om = ', line)
    line = re.sub(r'\bbit \[2:0\] erc\b\s*=', 'erc_val =', line)
    line = re.sub(r'\bbit \[31:0\] mv\b\s*=', 'mv =', line)

    out.append(line)

with open('d:/mywork/vsc000/ERMU_UT/test/ermu_stress_test.sv', 'w', encoding='utf-8') as f:
    f.writelines(out)
print('done')
