// FILE: Sales.Api.Queries\UserQuery\GetUserByUsernameQuery.cs

using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.UserQuery;

public class GetUserByUsernameQuery : IRequest<UserDto?>
{
    public string Username { get; }
    public GetUserByUsernameQuery(string username) { Username = username; }

    public class GetUserByUsernameQueryHandler : IRequestHandler<GetUserByUsernameQuery, UserDto?>
    {
        private readonly UserRepository _repository;

        public GetUserByUsernameQueryHandler(UserRepository repository)
        {
            _repository = repository;
        }

        public async Task<UserDto?> Handle(GetUserByUsernameQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByUsernameAsync(request.Username);
            return entity == null ? null : MapperUser.MapToUserDto(entity);
        }
    }
}
