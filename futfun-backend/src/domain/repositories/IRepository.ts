export interface IRepository<T> {
  create(data: T): Promise<T>;
  findById(id: string): Promise<T | null>;
  update(id: string, data: Partial<T>): Promise<T>;
  delete(id: string): Promise<void>;
  findAll(): Promise<T[]>;
}
