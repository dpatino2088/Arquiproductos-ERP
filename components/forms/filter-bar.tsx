import { Input } from '@/components/ui/input';
import { Select } from '@/components/ui/select';

interface FilterBarProps {
  placeholder?: string;
  statusOptions?: string[];
}

export function FilterBar({ placeholder = 'Buscar...', statusOptions }: FilterBarProps) {
  return (
    <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
      <Input placeholder={placeholder} className="md:max-w-sm" />
      {statusOptions && statusOptions.length > 0 ? (
        <Select defaultValue="">
          <option value="">Todos los estados</option>
          {statusOptions.map((opt) => (
            <option key={opt} value={opt}>
              {opt}
            </option>
          ))}
        </Select>
      ) : null}
    </div>
  );
}

