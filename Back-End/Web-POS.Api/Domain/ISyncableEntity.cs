namespace Api.Domain
{
    /// <summary>
    /// Marks an entity as participating in delta-sync. The
    /// <see cref="LastModified"/> column is auto-stamped by
    /// <c>AppDbContext.SaveChangesAsync</c> on every INSERT/UPDATE,
    /// so call sites never set it manually.
    /// </summary>
    public interface ISyncableEntity
    {
        DateTime LastModified { get; set; }
    }
}
