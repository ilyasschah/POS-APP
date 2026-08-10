using Api.Master;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace Api.Tests;

/// <summary>
/// A throwaway <see cref="MasterDbContext"/> backed by an in-memory SQLite file.
///
/// Deliberately the REAL context and the REAL entity model, not a stub: the point
/// of these tests is the seeder's and the credential service's behaviour against
/// EF, and a fake store would only pin the fake. The schema comes from
/// <c>EnsureCreated()</c> rather than the SQL Server DDL in AdminUserSeeder,
/// because that DDL is T-SQL — it is verified directly against the live master
/// database instead.
/// </summary>
public sealed class MasterDbFixture : IDisposable
{
    private readonly SqliteConnection _connection;

    public MasterDbFixture()
    {
        // Shared-cache in-memory: the database lives exactly as long as this
        // connection, so each fixture is fully isolated from every other test.
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        using var db = NewContext();
        db.Database.EnsureCreated();
    }

    public MasterDbContext NewContext() =>
        new(new DbContextOptionsBuilder<MasterDbContext>()
            .UseSqlite(_connection)
            .Options);

    public void Dispose() => _connection.Dispose();
}
