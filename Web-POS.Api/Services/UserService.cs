using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class UserService
    {
        public readonly UserRepository _repository;

        public UserService(UserRepository repository)
        {
            _repository = repository;
        }
        
        public async Task<User> Create(CreateUserRequest req, int companyId)
        {
            if (await _repository.ExistsAsync(req.Username, companyId))
                throw new InvalidOperationException($"A User with the username '{req.Username}' already exists.");
            var entity = User.Create(
                username: req.Username,
                password: req.Password,
                companyId: companyId
            );
            entity.CompanyId = companyId;
            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdateUserRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId, trackEntity: true);
            if (entity == null) return false;
            if (!string.IsNullOrWhiteSpace(req.Username))
            {
                var existsUsername = await _repository.GetByUsernameAsync(req.Username, companyId);
                if (existsUsername != null && existsUsername.Id != id)
                    throw new InvalidOperationException($"Another User with the username '{req.Username}' already exists.");
            }
            entity.Update(
                companyId: companyId,
                username: req.Username,
                firstName: req.FirstName,
                lastName: req.LastName,
                accessLevel: req.AccessLevel,
                isEnabled: req.IsEnabled,
                email: req.Email
            );

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId);
            if (entity == null) return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}