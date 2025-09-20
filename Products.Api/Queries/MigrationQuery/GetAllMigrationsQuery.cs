using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.MigrationQuery
{
    public class GetAllMigrationsQuery : IRequest<List<MigrationDto>>
    {
        public class GetAllMigrationsQueryHandler : IRequestHandler<GetAllMigrationsQuery, List<MigrationDto>>
        {
            private readonly MigrationRepository _repository;

            public GetAllMigrationsQueryHandler(MigrationRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<MigrationDto>> Handle(GetAllMigrationsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync();
                return list.Select(MapperMigration.MapToMigrationDto).ToList();
            }
        }
    }
}
