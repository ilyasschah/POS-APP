// FILE: Products.Api.Queries\UserQuery\GetAllUsersQuery.cs

using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.UserQuery;

public class GetAllUsersQuery : IRequest<List<UserDto>>
{
    public int CompanyId { get; set; }

    public class GetAllUsersQueryHandler : IRequestHandler<GetAllUsersQuery, List<UserDto>>
    {
        private readonly UserRepository _repository;

        public GetAllUsersQueryHandler(UserRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<UserDto>> Handle(GetAllUsersQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync(request.CompanyId);
            return entities.Select(MapperUser.MapToUserDto).ToList();
        }
    }
}
