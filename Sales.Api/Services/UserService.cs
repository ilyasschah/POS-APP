using Sales.Api.Domain;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Services
{
    public class UserService
    {
        public readonly UserRepository _repository;

        public UserService(UserRepository repository)
        {
            _repository = repository;
        }

        public async Task<bool> Create(CreateUserRequest req)
        {
            if (_repository.Exists(req.Username))
                throw new InvalidOperationException($"A User with the username '{req.Username}' already exists.");

            // TODO: Implement password hashing here (e.g., using BCrypt.Net)
            var hashedPassword = req.Password; // Replace this line with a real hashing call

            var newEntity = User.Create(req.Username, hashedPassword);
            newEntity.Update(req.FirstName, req.LastName, req.Username, req.AccessLevel, req.IsEnabled, req.Email);

            await _repository.AddAsync(newEntity);
            return true;
        }

        public async Task<bool> Update(UpdateUserRequest req)
        {
            var entity = await _repository.GetByIdAsync(req.Id);
            if (entity == null)
                throw new InvalidOperationException($"A User with the ID '{req.Id}' does not exist.");

            entity.Update(req.FirstName, req.LastName, req.Username, req.AccessLevel, req.IsEnabled, req.Email);

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id);
            if (entity == null)
                return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}