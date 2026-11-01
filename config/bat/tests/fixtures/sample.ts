// Environment X Syntax Test Fixture: TypeScript
export type Status = "active" | "idle" | "terminated";

export interface NodeMetadata<T = Record<string, unknown>> {
  id: string;
  uptime: number;
  status: Status;
  attributes: T;
}

export class ClusterSupervisor<T> {
  private readonly nodes = new Map<string, NodeMetadata<T>>();

  constructor(public readonly clusterName: string) {}

  public register(node: NodeMetadata<T>): boolean {
    if (this.nodes.has(node.id)) {
      throw new Error(`Node collision: ${node.id}`);
    }
    this.nodes.set(node.id, { ...node, status: "active" });
    return true;
  }

  public async broadcast(message: string): Promise<number> {
    const activeNodes = Array.from(this.nodes.values()).filter(
      (n) => n.status === "active"
    );
    return Promise.resolve(activeNodes.length);
  }
}
