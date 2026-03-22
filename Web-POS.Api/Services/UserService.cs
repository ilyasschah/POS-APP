using Api.Domain;
using Api.Models;
using Api.Repository;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    public class UserService
    {
        public readonly UserRepository _userrepository;
        public readonly CompanyRepository _companyRepository;

        public UserService(UserRepository Userrepository, CompanyRepository companyRepository)
        {
            _userrepository = Userrepository;
            _companyRepository = companyRepository;
        }
        
        public async Task<UserDto> CreateAsync(CreateUserRequest req, int companyId)
        {
            if (await _userrepository.ExistsAsync(req.Username, companyId))
                throw new InvalidOperationException($"A User with the username '{req.Username}' already exists.");
            var entity = User.Create(
                companyId,
                req.FirstName,
                req.LastName,
                req.Username,
                req.Password,
                req.AccessLevel,
                req.IsEnabled,
                req.Email
            );
            await _userrepository.AddAsync(entity);
            return new UserDto
            {
                Id = entity.Id,
                FirstName = entity.FirstName,
                LastName = entity.LastName,
                Username = entity.Username,
                AccessLevel = entity.AccessLevel,
                IsEnabled = entity.IsEnabled,
                Email = entity.Email
            };
        }

        public async Task<bool> Update(UpdateUserRequest req, int companyId)
        {
            var entity = await _userrepository.GetByIdAsync(req.Id, companyId);
            if (entity == null) return false;
            if (!string.IsNullOrWhiteSpace(req.Username) && req.Username != entity.Username)
            {
                var existsUsername = await _userrepository.GetByUsernameAsync(req.Username, companyId);
                if (existsUsername != null && existsUsername.Id != req.Id)
                        throw new InvalidOperationException($"Another User with the username '{req.Username}' already exists.");
            }
            entity.Username = req.Username ?? entity.Username;
            entity.FirstName = req.FirstName ?? entity.FirstName;
            entity.LastName = req.LastName ?? entity.LastName;
            entity.AccessLevel = req.AccessLevel ?? entity.AccessLevel;
            entity.IsEnabled = req.IsEnabled ?? entity.IsEnabled;
            entity.Email = req.Email ?? entity.Email;

            await _userrepository.UpdateAsync(entity);

            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var entity = await _userrepository.GetByIdAsync(id, companyId);
            if (entity == null)
            {
                throw new KeyNotFoundException($"User with ID {id} not found.");
            }

            try
            {
                await _userrepository.DeleteAsync(id, companyId);
                return true;
            }
            catch (DbUpdateException ex) when (ex.InnerException is SqlException sqlEx && sqlEx.Number == 547)
            {
                // SQL Error 547 specifically means a Foreign Key constraint violation
                throw new InvalidOperationException("This user has a document related to their name, so you cannot delete it.");
            }
        }
    }
}