using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;
namespace Products.Api.Repository
{
    public class SecurityKeyRepository
    {
        public AppDbContext _db;
        public SecurityKeyRepository(AppDbContext db)
        {
            _db = db;
        }
        public async Task<List<SecurityKey>> GetSecurityKeysAsync()
        {
            return await _db.SecurityKeys
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task Add(SecurityKey newSecurityKey)
        {
            _db.SecurityKeys.Add(newSecurityKey);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(SecurityKey securityKey)
        {
            _db.SecurityKeys.Remove(securityKey);
            await _db.SaveChangesAsync();
        }
        public bool Exist(string keyName)
        {
            return _db.SecurityKeys.Any(sk => sk.Name == keyName);
        }
    }
}
