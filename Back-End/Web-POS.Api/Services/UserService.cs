using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    public class UserService
    {
        private readonly UserRepository _userrepository;
        private readonly CompanyRepository _companyRepository;

        public UserService(UserRepository userRepository, CompanyRepository companyRepository)
        {
            _userrepository = userRepository;
            _companyRepository = companyRepository;
        }

        public async Task<UserDto> CreateAsync(CreateUserRequest req, int companyId)
        {
            if (await _userrepository.ExistsAsync(req.Username, companyId))
                throw new InvalidOperationException($"A User with the username '{req.Username}' already exists.");

            string hashedPassword = BCrypt.Net.BCrypt.HashPassword(req.Password);

            var entity = User.Create(
                companyId,
                req.FirstName,
                req.LastName,
                req.Username,
                hashedPassword, 
                req.AccessLevel,
                req.IsEnabled,
                req.Email
            );

            await _userrepository.AddAsync(entity);
            return MapperUser.MapToUserDto(entity);
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

            entity.Update(
                firstName: req.FirstName ?? entity.FirstName,
                lastName: req.LastName ?? entity.LastName,
                username: req.Username ?? entity.Username!,
                accessLevel: req.AccessLevel ?? entity.AccessLevel,
                isEnabled: req.IsEnabled ?? entity.IsEnabled,
                email: req.Email ?? entity.Email
            );

            await _userrepository.UpdateAsync(entity);

            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            try
            {
                await _userrepository.DeleteAsync(id, companyId);
                return true;
            }
            catch (InvalidOperationException)
            {
                throw new KeyNotFoundException($"User with ID {id} not found.");
            }
            // 547 is SQL Server's foreign-key violation. Every remaining
            // referencer of User is business history — sales, payments,
            // bookings, voids, starting cash — because the one thing that is
            // NOT history, the user's device PINs, is removed with them by
            // UserRepository.DeleteAsync. Before that, a user whose only tie
            // was a till PIN was refused with this same sentence, which sent
            // people hunting for a document that did not exist.
            catch (DbUpdateException ex) when (ex.InnerException is SqlException sqlEx && sqlEx.Number == 547)
            {
                throw new InvalidOperationException(
                    "This user is named on sales history — orders, payments, bookings "
                  + "or voids — which cannot be reassigned, so the account cannot be "
                  + "deleted. Disable it instead: they keep their history and can no "
                  + "longer sign in.");
            }
        }
    }
}