import bcrypt from 'bcrypt';

const COST = 12;

export const hashPassword = (plain: string): Promise<string> => bcrypt.hash(plain, COST);
export const verifyPassword = (plain: string, hash: string): Promise<boolean> =>
  bcrypt.compare(plain, hash);
