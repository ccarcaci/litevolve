export class migration_error extends Error {
  constructor(
    public module_path: string,
    public method: string,
    public override cause: string,
    public original_error?: unknown,
  ) {
    super(cause)
    Object.setPrototypeOf(this, new.target.prototype)
  }
}
