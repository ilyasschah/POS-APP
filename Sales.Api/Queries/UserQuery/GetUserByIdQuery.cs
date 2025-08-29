// FILE: Sales.Api.Queries\UserQuery\GetUserByIdQuery.cs

using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.UserQuery;

public class GetUserByIdQuery : IRequest<UserDto?>
{
    public int Id { get; }
    public GetUserByIdQuery(int id) { Id = id; }

    public class GetUserByIdQueryHandler : IRequestHandler<GetUserByIdQuery, UserDto?>
    {
        private readonly UserRepository _repository;

        public GetUserByIdQueryHandler(UserRepository repository)
        {
            _repository = repository;
        }

        public async Task<UserDto?> Handle(GetUserByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByIdAsync(request.Id);
            return entity == null ? null : MapperUser.MapToUserDto(entity);
        }
    }
}
